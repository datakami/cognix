// source: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/stream_layered_image.py
// This script generates a Docker image from a set of nix store paths.

// It expects a JSON file with the following properties and writes the
// image to the local demon or pushes it to a registry:

// * "architecture", "config", "os", "created", "repo_tag" correspond to
//   the fields with the same name on the [tarball] image spec.
// * "created" can be "now".
// * "created" is also used as mtime for files added to the image.
// * "store_layers" is a list of layers in ascending order, where each
//   layer is the list of store paths to include in that layer.

package main

import (
	"encoding/json"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"fmt"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/daemon"
	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/types"

	"github.com/datakami/cognix/pkgs/stream_layered_image/nix"
	"github.com/google/go-containerregistry/pkg/crane"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/spf13/cobra"
	"golang.org/x/term"

	"github.com/google/go-containerregistry/pkg/logs"
)

var (
	debugMode = false
	sToken    string
	sTag      string
	sRegistry string = "r8.im"
)

func debug(msg ...any) {
	if debugMode {
		fmt.Fprintln(os.Stderr, msg...)
	}
}

// def add_layer_dir(tar, paths, store_dir, mtime):
//     """
//     Appends given store paths to a TarFile object as a new layer.
//     tar: 'tarfile.TarFile' object for the new layer to be added to.
//     paths: List of store paths.
//     store_dir: the root directory of the nix store
//     mtime: 'mtime' of the added files and the layer tarball.
//            Should be an integer representing a POSIX time.
//     Returns: A 'LayerInfo' object containing some metadata of
//              the layer added.
//     """
//     invalid_paths = [i for i in paths if not i.startswith(store_dir)]
//     assert len(invalid_paths) == 0, \
//         f"Expecting absolute paths from {store_dir}, but got: {invalid_paths}"
//     # First, calculate the tarball checksum and the size.
//     extract_checksum = ExtractChecksum()
//     archive_paths_to(
//         extract_checksum,
//         paths,
//         mtime=mtime,
//     )
//     (checksum, size) = extract_checksum.extract()
//     path = f"{checksum}/layer.tar"
//     layer_tarinfo = tarfile.TarInfo(path)
//     layer_tarinfo.size = size
//     layer_tarinfo.mtime = mtime
//     # Then actually stream the contents to the outer tarball.
//     read_fd, write_fd = os.pipe()
//     with open(read_fd, "rb") as read, open(write_fd, "wb") as write:
//         def producer():
//             archive_paths_to(
//                 write,
//                 paths,
//                 mtime=mtime,
//             )
//             write.close()

//         # Closing the write end of the fifo also closes the read end,
//         # so we don't need to wait until this thread is finished.
//         #
//         # Any exception from the thread will get printed by the default
//         # exception handler, and the 'addfile' call will fail since it
//         # won't be able to read required amount of bytes.
//         threading.Thread(target=producer).start()
//         tar.addfile(layer_tarinfo, read)
//     return LayerInfo(size=size, checksum=checksum, path=path, paths=paths)

func addLayerDir(paths []string, mtime int64, layerType types.MediaType) mutate.Addendum {
	// given store paths as a layer with history
	// affix.go: "All of this code is from pkg/v1/mutate - so we can add history and use a tarball"

	// baseMediaType, err := base.MediaType()
	// if err != nil {
	// 	return nil, fmt.Errorf("getting base image media type: %w", err)
	// }

	layer := nix.NewLayer(paths, mtime, false, layerType)
	history := v1.History{
		Created: v1.Time{Time: time.Unix(mtime, 0)},
		Comment: fmt.Sprintf("store paths: %s", paths),
	}
	return mutate.Addendum{Layer: layer, History: history}
}

// def add_customisation_layer(target_tar, customisation_layer, mtime):
//     """
//     Adds the customisation layer as a new layer. This is layer is structured
//     differently; given store path has the 'layer.tar' and corresponding
//     sha256sum ready.
//     tar: 'tarfile.TarFile' object for the new layer to be added to.
//     customisation_layer: Path containing the layer archive.
//     mtime: 'mtime' of the added layer tarball.
//     """
//     checksum_path = os.path.join(customisation_layer, "checksum")
//     with open(checksum_path) as f:
//         checksum = f.read().strip()
//     assert len(checksum) == 64, f"Invalid sha256 at ${checksum_path}."
//     layer_path = os.path.join(customisation_layer, "layer.tar")
//     path = f"{checksum}/layer.tar"
//     tarinfo = target_tar.gettarinfo(layer_path)
//     tarinfo.name = path
//     tarinfo.mtime = mtime
//     with open(layer_path, "rb") as f:
//         target_tar.addfile(tarinfo, f)
//     return LayerInfo(
//       size=None,
//       checksum=checksum,
//       path=path,
//       paths=[customisation_layer]
//     )

func addCustomizationLayer(customisation_layer string, mtime int64, layerType types.MediaType) mutate.Addendum {
	// in python this is getting streamed into docker load, following that format for multiple layers
	// here we're just creating a layer object, we shouldn't even need to check the checksum
	// 	// checksum_path := filepath.Join(customisation_layer, "checksum")
	// 	// checksum := ""
	// 	// if f, err := os.Open(checksum_path); err == nil {
	// 	// 	buf := new(bytes.Buffer)
	// 	// 	buf.ReadFrom(f)
	// 	// 	checksum = buf.String()
	// 	// }
	// 	// if len(checksum) != 64 {
	// 	// 	fmt.Fprintln(os.Stderr, "Invalid sha256 at", checksum_path)
	// 	// }
	// 	// path := fmt.Sprintf("%s/layer.tar", checksum)
	path := fmt.Sprintf("%s/layer.tar", customisation_layer)
	layer, err := tarball.LayerFromFile(path, tarball.WithMediaType(layerType))
	if err != nil {
		panic(err)
	}
	history := v1.History{
		Created: v1.Time{Time: time.Unix(int64(mtime), 0)},
		Comment: fmt.Sprintf("store paths: %s", customisation_layer),
	}
	return mutate.Addendum{Layer: layer, History: history}

}

// def overlay_base_config(from_image, final_config):
//     """
//     Overlays the final image 'config' JSON on top of selected defaults from the
//     base image 'config' JSON.
//     from_image: 'FromImage' object with references to the loaded base image.
//     final_config: 'dict' object of the final image 'config' JSON.
//     """
//     if from_image is None:
//         return final_config
//     base_config = from_image.image_json["config"]
//     # Preserve environment from base image
//     final_env = base_config.get("Env", []) + final_config.get("Env", [])
//     if final_env:
//         # Resolve duplicates (last one wins) and format back as list
//         resolved_env = {entry.split("=", 1)[0]: entry for entry in final_env}
//         final_config["Env"] = list(resolved_env.values())
//     return final_config

func overlayBaseConfig(base_config v1.Config, final_config v1.Config) v1.Config {
	// Preserve environment from base image
	final_env := append(base_config.Env, final_config.Env...)
	// Resolve duplicates (last one wins) and format back as list
	resolved_env := make(map[string]string)
	for _, entry := range final_env {
		parts := strings.SplitN(entry, "=", 2)
		resolved_env[parts[0]] = entry
	}
	final_config.Env = []string{}
	// iterate in order, remove from map
	for _, entry := range final_env {
		parts := strings.SplitN(entry, "=", 2)
		c, ok := resolved_env[parts[0]]
		if ok {
			final_config.Env = append(final_config.Env, c)
			delete(resolved_env, parts[0])
		}
	}
	return final_config
}

type Conf struct {
	FromImage          string     `json:"from_image"`
	StoreLayers        [][]string `json:"store_layers"`
	CustomisationLayer string     `json:"customisation_layer"`
	RepoTag            string     `json:"repo_tag"`
	Created            string     `json:"created"`
	Config             v1.Config  `json:"config"`
	Architecture       string     `json:"architecture"`
	StoreDir           string     `json:"store_dir"`
}

func checkValidPaths(conf Conf) error {
	// invalid_paths = [i for i in paths if not i.startswith(store_dir)]
	// assert len(invalid_paths) == 0, \
	//     f"Expecting absolute paths from {store_dir}, but got: {invalid_paths}"
	for _, layer := range conf.StoreLayers {
		for _, path := range layer {
			if !strings.HasPrefix(path, conf.StoreDir) {
				return fmt.Errorf("Expecting absolute paths from %s, but got: %s", conf.StoreDir, path)
			}
		}
	}
	return nil
}

func makeImage(specfile string) (error, v1.Image, *name.Tag) {
	conf_bytes, _ := os.ReadFile(specfile)
	var conf Conf
	err := json.Unmarshal(conf_bytes, &conf)
	if err != nil {
		return fmt.Errorf("parsing config: %w", err), nil, nil
	}

	checkValidPaths(conf)

	tag, err := name.NewTag(conf.RepoTag)
	if err != nil {
		return fmt.Errorf("parsing tag: %w", err), nil, nil
	}

	created := time.Now()
	if conf.Created != "now" {
		created, _ = time.Parse(time.RFC3339, conf.Created)
	}
	mtime := int64(created.Unix())

	configFile := &v1.ConfigFile{}
	if conf.FromImage != "" {
		return fmt.Errorf("we don't support base images yet"), nil, &tag
	}

	baseMediaType := types.DockerManifestSchema1
	//baseMediaType := types.DockerManifestSchema2 // default!
	layerType := types.DockerLayer
	if baseMediaType == types.OCIManifestSchema1 {
		layerType = types.OCIUncompressedLayer
	}

	layers := make([]mutate.Addendum, len(conf.StoreLayers)+1)
	var wg sync.WaitGroup
	wg.Add(len(conf.StoreLayers) + 1)
	for index, store_layer := range conf.StoreLayers {
		/* go */ func(index int, store_layer []string) {
			defer wg.Done()
			layers[index] = addLayerDir(store_layer, mtime, layerType)
		}(index, store_layer)
	}
	fmt.Fprintln(os.Stderr, "Creating layer", len(layers), "with customisation...")
	/* go */ func() {
		defer wg.Done()
		layers[len(layers)-1] = addCustomizationLayer(conf.CustomisationLayer, mtime, layerType)
	}()
	wg.Wait()
	// if the last layer is nil, remove it
	// this is dumb, for testing purposes
	if layers[len(layers)-1].Layer == nil {
		layers = layers[:len(layers)-1]
	}
	// print out raw values of layers
	debug("layers:", layers)
	debug("running mutate.Append(from_image, layers...)")
	image, err := mutate.Append(empty.Image, layers...)
	if err != nil || image == nil {
		return fmt.Errorf("appending layers: %w", err), nil, &tag
	}
	debug("resulting image is now:", image)

	// image_json = {
	// 	"created": datetime.isoformat(created),
	// 	"architecture": conf["architecture"],
	// 	"os": "linux",
	// 	"config": overlay_base_config(from_image, conf["config"]),
	// 	"rootfs": {
	// 		"diff_ids": [f"sha256:{layer.checksum}" for layer in layers],
	// 		"type": "layers",
	// 	},
	// 	"history": [
	// 		{
	// 			"created": datetime.isoformat(created),
	// 			"comment": f"store paths: {layer.paths}"
	// 		}
	// 		for layer in layers
	// 	],
	// }
	configFile, err = image.ConfigFile()
	if err != nil {
		panic(err)
	}
	configFile.Config = overlayBaseConfig(configFile.Config, conf.Config)
	configFile.Created = v1.Time{Time: created}
	configFile.Architecture = conf.Architecture
	configFile.OS = "linux"
	debug("image", image)
	debug("configFile", configFile)
	debug("running mutate.ConfigFile(image, configFile)")
	image, err = mutate.ConfigFile(image, configFile)

	//debug("resulting image is now:", image)
	if err != nil {
		return fmt.Errorf("setting config file: %w", err), nil, &tag
	}

	return nil, image, &tag
}

func pushImage(img v1.Image, dest string, auth authn.Authenticator) (string, error) {
	// --- pushing image
	start := time.Now()

	err := crane.Push(img, dest, crane.WithAuth(auth))
	if err != nil {
		return "", fmt.Errorf("pushing %s: %w", dest, err)
	}

	fmt.Fprintln(os.Stderr, "pushing took", time.Since(start))

	d, err := img.Digest()
	if err != nil {
		return "", err
	}
	image_id := fmt.Sprintf("%s@%s", dest, d)
	return image_id, nil
}

func addressWithScheme(address string) string {
	if strings.Contains(address, "://") {
		return address
	}
	return "https://" + address
}

func VerifyCogToken(registryHost string, token string) (username string, err error) {
	if token == "" {
		return "", fmt.Errorf("token is required")
	}

	resp, err := http.PostForm(addressWithScheme(registryHost)+"/cog/v1/verify-token", url.Values{
		"token": []string{token},
	})
	if err != nil {
		return "", fmt.Errorf("failed to verify token: %w", err)
	}
	if resp.StatusCode == http.StatusNotFound {
		return "", fmt.Errorf("user does not exist")
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("failed to verify token, got status %d", resp.StatusCode)
	}
	defer resp.Body.Close()
	body := &struct {
		Username string `json:"username"`
	}{}
	if err := json.NewDecoder(resp.Body).Decode(body); err != nil {
		return "", err
	}
	return body.Username, nil
}

func getAuth() authn.Authenticator {
	if sToken == "" {
		sToken = os.Getenv("REPLICATE_API_TOKEN")
	}

	if sToken == "" {
		sToken = os.Getenv("COG_TOKEN")
	}

	u, err := VerifyCogToken(sRegistry, sToken)
	if err != nil {
		fmt.Fprintln(os.Stderr, "authentication error, invalid token or registry host error")
	}
	return authn.FromConfig(authn.AuthConfig{Username: u, Password: sToken})
}

func getSpecFile(args []string) string {
	specFile := os.Getenv("CN_SPEC_FILE")
	if specFile == "" {
		return args[0]
	}
	return specFile
}

func pushCommand(_ *cobra.Command, args []string) error {
	err, image, _ := makeImage(getSpecFile(args))
	if err != nil {
		return err
	}
	auth := getAuth()

	url := args[0]
	if os.Getenv("CN_SPEC_FILE") == "" {
		url = args[1]
	}
	id, err := pushImage(image, url, auth)
	if err != nil {
		return err
	}

	fmt.Fprintf(os.Stdout, "%s\n", id)
	return nil
}

func loadCommand(_ *cobra.Command, args []string) error {
	err, image, tag := makeImage(getSpecFile(args))
	if sTag != "" {
		pTag, err := name.NewTag(sTag)
		if err != nil {
			return fmt.Errorf("parsing tag: %w", err)
		}
		tag = &pTag
	}
	_, err = daemon.Write(*tag, image)
	if err != nil {
		return fmt.Errorf("writing to local daemon: %w", err)
	}
	fmt.Fprintf(os.Stdout, "%s\n", tag)
	return nil
}

func dumpCommand(_ *cobra.Command, args []string) error {
	err, image, tag := makeImage(getSpecFile(args))
	if err != nil {
		return fmt.Errorf("dumping archive: %w", err)
	}
	return tarball.Write(tag, image, os.Stdout)
}

func pushLayeredImageCommand(cmd *cobra.Command, args []string) error {
	if term.IsTerminal(int(os.Stdout.Fd())) {
		return cmd.Help()
	} else {
		fmt.Fprintln(os.Stderr, "Note: defaulting to `dump` mode because the output is redirected")
		if len(args) != 1 {
			return fmt.Errorf("accepts 1 arg, received %d", len(args))
		}
		return dumpCommand(cmd, args)
	}
}

func newPushLayeredImageCommand() *cobra.Command {
	specFileCnt := 0
	specFileArg := " spec.json"
	// support passing spec file through env variable
	if os.Getenv("CN_SPEC_FILE") != "" {
		specFileCnt = 1
		specFileArg = ""
	}
	cmd := &cobra.Command{
		Use:     "stream_layered_image",
		Short:   "docker image builder for nix-dockerTools",
		Hidden:  false,
		RunE:    pushLayeredImageCommand,
		Args:    cobra.MaximumNArgs(1 - specFileCnt),
		Version: "0.0.1",
	}
	cmd.PersistentFlags().BoolVarP(&debugMode, "debug", "d", false, "enable debug output")

	push := &cobra.Command{
		Use:   "push [-t token]" + specFileArg + " url",
		RunE:  pushCommand,
		Args:  cobra.ExactArgs(2 - specFileCnt),
		Short: "push an image to an external registry",
	}
	push.Flags().StringVarP(&sToken, "token", "t", "", "replicate api token")
	cmd.AddCommand(push)
	load := &cobra.Command{
		Use:   "load" + specFileArg,
		RunE:  loadCommand,
		Args:  cobra.ExactArgs(1 - specFileCnt),
		Short: "load an image into a locally running docker daemon",
	}
	load.Flags().StringVarP(&sTag, "tag", "", "", "tagname, defaults to nix hash")
	cmd.AddCommand(load)
	cmd.AddCommand(
		&cobra.Command{
			Use:   "dump" + specFileArg,
			RunE:  dumpCommand,
			Args:  cobra.ExactArgs(1 - specFileCnt),
			Short: "dump an image to stdout",
		},
	)
	return cmd
}

func main() {
	cmd := newPushLayeredImageCommand()

	logs.Warn = log.New(os.Stderr, "gcr WARN: ", log.LstdFlags)
	logs.Progress = log.New(os.Stderr, "gcr: ", log.LstdFlags)

	if err := cmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
