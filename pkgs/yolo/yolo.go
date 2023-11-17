package main

import (
	"fmt"
	"log"
	"os"

	"github.com/google/go-containerregistry/pkg/logs"
	"github.com/spf13/cobra"
)

func main() {
	cmd, err := NewRootCommand()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	if err = cmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func NewRootCommand() (*cobra.Command, error) {
	rootCmd := cobra.Command{
		Use:           "yolo",
		Short:         "remix the web",
		Version:       "0.0.1",
		SilenceErrors: true,
	}

	rootCmd.AddCommand(
		newPushLayeredImageCommand(),
	)
	logs.Warn = log.New(os.Stderr, "gcr WARN: ", log.LstdFlags)
	logs.Progress = log.New(os.Stderr, "gcr: ", log.LstdFlags)

	return &rootCmd, nil
}
