# Uberwald

## DEPRECATED

The cluster has been decommisioned. Applications running in the cluster were removed or migrated:
- `news` has been removed completely as `news.krupa.net.pl` wasn't used
- `blog` was converted to a simple landing page hosted on netlify (https://github.com/paulfantom/landing)
- `recipe` was moved to ankhmorpork cluster

## What is it?

This is a part of [@paulfantom](https://github.com/paulfantom) personal homelab. It is on purpose made public to be used as:
- a configuration example
- a proof that cluster configuration can live in the open and be secure

## How dos it work?

Configuration is divided into three directories and is managed in two ways - either by terraform or by flux.

#### Terraform

Terraform is used to manage Civo kubernetes cluster.

#### Base

Directory contains all base application of k3s cluster. Initial bootstrap should be done manually with kubectl and after
that updates are performed by flux.

Additionally it is a place where flux apps and projects are stored.

#### Apps

Every other service that is installed into a cluster goes into `apps/` directory which should be governed by flux.

## Security

If you find any security issue please ping me using one of following contact mediums:
- twitter DM (@paulfantom)
- kubernetes slack (@paulfantom)
- freenode IRC (@paulfantom)
- email (paulfantom+security@gmail.com)
