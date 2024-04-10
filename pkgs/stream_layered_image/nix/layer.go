package nix

import (
	"archive/tar"
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"

	"github.com/google/go-containerregistry/pkg/v1/types"

	v1 "github.com/google/go-containerregistry/pkg/v1"
)

type nixLayer struct {
	paths    []string
	mtime    int64
	compress bool
	mt       types.MediaType

	once sync.Once
	h    v1.Hash
	b    []byte
}

func appendRoot(ti *tar.Header) *tar.Header {
	// python "gettarinfo makes the paths relative, this makes them absolute again"
	// unclear what FileInfoHeader does
	if ti.Name[0] != '/' {
		ti.Name = "/" + ti.Name
	}
	return ti
}
func _applyFilters(mtime int64, ti *tar.Header) *tar.Header {
	ti.ModTime = time.Unix(mtime, 0)
	ti.Uid = 0
	ti.Gid = 0
	ti.Uname = "root"
	ti.Gname = "root"
	return ti
}
func nixRoot(ti *tar.Header) *tar.Header {
	ti.Mode = 0o0555 // r-xr-xr-x
	return ti
}
func dir(path string) *tar.Header {
	ti := &tar.Header{Name: path, Typeflag: tar.TypeDir}
	return ti
}

func getFilesForPath(path string) []string {
	var files []string
	if info, _ := os.Lstat(path); info.Mode()&os.ModeSymlink != 0 {
		return []string{path}
	}
	_ = filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
		files = append(files, path)
		return nil
	})
	return files
}

// def archive_paths_to(obj, paths, mtime):
//     """
//     Writes the given store paths as a tar file to the given stream.
//     obj: Stream to write to. Should have a 'write' method.
//     paths: List of store paths.
//     """
//     # gettarinfo makes the paths relative, this makes them
//     # absolute again
//     def append_root(ti):
//         ti.name = "/" + ti.name
//         return ti
//     def apply_filters(ti):
//         ti.mtime = mtime
//         ti.uid = 0
//         ti.gid = 0
//         ti.uname = "root"
//         ti.gname = "root"
//         return ti
//     def nix_root(ti):
//         ti.mode = 0o0555  # r-xr-xr-x
//         return ti
//     def dir(path):
//         ti = tarfile.TarInfo(path)
//         ti.type = tarfile.DIRTYPE
//         return ti
//     with tarfile.open(fileobj=obj, mode="w|") as tar:
//         # To be consistent with the docker utilities, we need to have
//         # these directories first when building layer tarballs.
//         tar.addfile(apply_filters(nix_root(dir("/nix"))))
//         tar.addfile(apply_filters(nix_root(dir("/nix/store"))))
//         for path in paths:
//             path = pathlib.Path(path)
//             if path.is_symlink():
//                 files = [path]
//             else:
//                 files = itertools.chain([path], path.rglob("*"))
//             for filename in sorted(files):
//                 ti = append_root(tar.gettarinfo(filename))
//                 # copy hardlinks as regular files
//                 if ti.islnk():
//                     ti.type = tarfile.REGTYPE
//                     ti.linkname = ""
//                     ti.size = filename.stat().st_size
//                 ti = apply_filters(ti)
//                 if ti.isfile():
//                     with open(filename, "rb") as f:
//                         tar.addfile(ti, f)
//                 else:
//                     tar.addfile(ti)

func archivePaths(paths []string, mtime int64) *bytes.Buffer {
	// Writes the given store paths as a tar file
	// paths: List of store paths.
	buf := new(bytes.Buffer)
	tw := tar.NewWriter(buf)
	applyFilters := func(ti *tar.Header) *tar.Header { return _applyFilters(mtime, ti) }

	tw.WriteHeader(applyFilters(nixRoot(dir("/nix/"))))
	tw.WriteHeader(applyFilters(nixRoot(dir("/nix/store/"))))
	for _, path := range paths {
		files := getFilesForPath(path)
		// stable order
		sort.Strings(files)

		for _, filename := range files {
			st, _ := os.Lstat(filename)
			link := ""
			if st.Mode()&os.ModeSymlink != 0 {
				link_, err := os.Readlink(filename)
				if err != nil {
					panic(err)
				}
				link = link_
			}
			ti, _ := tar.FileInfoHeader(st, link)
			if st.IsDir() {
				ti.Name = filename + "/"
			} else {
				ti.Name = filename
			}
			ti = appendRoot(ti)

			// "copy hardlinks as regular files"
			// I don't think go even is aware of hardlinks?
			if ti.Typeflag == tar.TypeLink {
				ti.Typeflag = tar.TypeReg
				ti.Linkname = ""
				deref_st, _ := os.Stat(filename)
				ti.Size = deref_st.Size()
			}
			ti = applyFilters(ti)
			// TODO: Go writes devmajor and devminor as '0000000', python and gnu tar write them
			// as \x00. This means the checksums are different.
			if ti.Typeflag == tar.TypeReg {
				f, _ := os.Open(filename)
				// this really needs to be done in parallel
				// but it needs to be in a consistent order
				// maybe look at the size of everything, precompute indexes into the tarball
				tw.WriteHeader(ti)
				io.Copy(tw, f)
				f.Close()
			} else {
				tw.WriteHeader(ti)
			}
		}
	}
	tw.Close()

	return buf
}

func (l *nixLayer) populate() error {

	var err error
	l.once.Do(func() {
		fmt.Fprintln(os.Stderr, "Creating layer from paths:", l.paths)
		layerData := archivePaths(l.paths, int64(l.mtime))
		l.b = layerData.Bytes()
		l.h, _, err = v1.SHA256(bytes.NewReader(l.b))
	})
	return err
}

func NewLayer(paths []string, mtime int64, compress bool, mt types.MediaType) v1.Layer {
	return &nixLayer{paths: paths, mtime: mtime, compress: compress, mt: mt}
}

// implements v1.Layer
func (l *nixLayer) Digest() (v1.Hash, error) {
	// TODO: cache this across invocations
	err := l.populate()
	return l.h, err
}

// implements v1.Layer
func (l *nixLayer) DiffID() (v1.Hash, error) {
	// TODO: cache this across invocations
	return l.Digest()
}

// implements v1.Layer
func (l *nixLayer) Compressed() (io.ReadCloser, error) {
	err := l.populate()
	if err != nil {
		return nil, err
	}
	return io.NopCloser(bytes.NewReader(l.b)), err
}

// implements v1.Layer
func (l *nixLayer) Uncompressed() (io.ReadCloser, error) {
	err := l.populate()
	if err != nil {
		return nil, err
	}
	return io.NopCloser(bytes.NewReader(l.b)), nil
}

// implements v1.Layer
func (l *nixLayer) Size() (int64, error) {
	// TODO: cache this across invocations
	err := l.populate()
	if err != nil {
		return 0, err
	}
	return int64(len(l.b)), nil
}

// implements v1.Layer
func (l *nixLayer) MediaType() (types.MediaType, error) {
	return l.mt, nil
}
