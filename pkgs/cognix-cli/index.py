import click
import subprocess
import json
import re
import os
from pathlib import Path

@click.group()
@click.option("--pkg", default=None, help="subpackage to build")
@click.option("--print-build-logs", "-L", is_flag=True)
@click.option("--impure", is_flag=True)
@click.option("--show-trace", is_flag=True)
@click.option("--verbose", "-v", is_flag=True)
@click.option("--option", multiple=True, nargs=2, type=str)
@click.pass_context
def cli(ctx, pkg, print_build_logs, impure, show_trace, verbose, option):
    ctx.ensure_object(dict)
    if pkg is None:
        if Path("flake.nix").exists():
            pkg = "default"
        else:
            pkg = Path(".").resolve().name
        if verbose:
            print("defaulting to package", pkg)
    ctx.obj["PKG"] = pkg
    fl = []
    if print_build_logs:
        fl.append("--print-build-logs")
    if impure:
        fl.append("--impure")
    if show_trace:
        fl.append("--show-trace")
    if verbose:
        fl.append("--verbose")
    for (n, v) in option:
        if v in ("true", "True"):
            fl.append("--" + n)
        elif v in ("false", "False"):
            fl.append("--no-" + n)
        else:
            fl.append("--" + n)
            fl.append(v)
    ctx.obj["verbose"] = verbose
    ctx.obj["nix-flags"] = fl
   
def call_nix(ctx, command, target, extra_flags=[], capture_output=False):
    invocation = ["nix", command] + ctx.obj["nix-flags"] + [ ".#" + ctx.obj["PKG"] + target ] + extra_flags
    if ctx.obj["verbose"]:
        # todo quotes
        print("$", " ".join(invocation))
    return subprocess.run(invocation, check=True, capture_output=capture_output)

# - cognix init

@cli.command()
@click.pass_context
def lock(cli):
    call_nix(cli, "run", ".lock")
    # todo: add lockfile to git (git add --intend-to-add?)

@cli.command()
# @click.option("-t", "--tag", default="")
@click.pass_context
def build(cli):
    call_nix(cli, "build", "", ["--no-link"])
    # hash = cli.invoke(load)
    # if tag:
    #     subprocess.run(["docker", "tag", hash, tag], check=True)


def get_tag(cmd: str) -> str:
    with open(cmd, "r") as f:
        file_content = f.read()
    json_path = re.search(r"(/nix/store/[-.+_0-9a-zA-Z]+\.json)", file_content).group(1)
    with open(json_path, "r") as f:
        json_content = json.load(f)
    return json_content["repo_tag"]
    
@cli.command()
@click.pass_context
def load(cli):
    cli.invoke(build)
    f = call_nix(cli, "build", "", ["--json", "--no-link"], capture_output=True)
    result = json.loads(f.stdout)
    cmd = result[0]["outputs"]["out"]
    tag = get_tag(cmd)
    if subprocess.run(["docker", "image", "inspect", tag], check=False, capture_output=True).returncode == 0:
        print("Already loaded into docker:", tag)
        return tag
    subprocess.run(f"{cmd} | docker load", check=True, shell=True)
    return tag

@cli.command()
@click.argument("args", nargs=-1)
@click.pass_context
def run(cli, args):
    tag = cli.invoke(load)
    subprocess.run(["docker", "run", "-it", "--rm", tag] + list(args), check=True)

@cli.command()
@click.argument("name", nargs=1)
@click.pass_context
def push(cli, name):
    tag = cli.invoke(load)
    subprocess.run(["docker", "tag", tag, name], check=True)
    subprocess.run(["docker", "push", name], check=True)

@cli.command(name="push-weights")
@click.pass_context
def push_weights(cli):
    # todo: gcloud login
    call_nix(cli, "run", ".push-weights")

@cli.command()
@click.pass_context
@click.argument("name", default=None, nargs=1, required=False)
@click.option("-i", multiple=True)
def predict(cli, name, i):
    # not done yet
    if name is None:
        name = cli.invoke(load)
    
    forwarded_args = []
    for j in i:
        forwarded_args.append("-i")
        forwarded_args.append(j)
    subprocess.run(["cog", "predict", name] + forwarded_args, check=True)
    # d = subprocess.run(["docker", "run", "--gpus", "all", "--rm", "--detach", "--publish", "5000:5000", name], check=True, capture_output=True)
    # container_id = d.stdout.decode("utf-8").strip()
    # args = {}
    # for j in i:
    #     name, val = j.split("=",1)
    #     args[name] = val
    # arg = {"input": args}
    # # TODO: wait for container to be ready, check how cog does that
    # subprocess.run(["curl", "-X", "POST", "-H", "Content-Type: application/json", "-d", json.dumps(arg), "http://localhost:5000/predictions"], check=True)
    # subprocess.run(["docker", "stop", container_id], check=True)
    
if __name__ == '__main__':
    cli(prog_name="cognix")
