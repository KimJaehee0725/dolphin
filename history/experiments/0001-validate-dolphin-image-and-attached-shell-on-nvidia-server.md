---
type: experiment
title: "Validate Dolphin image and attached shell on NVIDIA server"
date: "2026-09-17 16:21 +0900"
status: complete
tags: [history, experiment, docker, validation, p10k]
---
# Experiment 0001 - Validate Dolphin image and attached shell on NVIDIA server

Date: 2026-09-17 16:21 +0900
Status: complete
Tags: docker, validation, p10k

## Goal

Prove the current Dockerfile builds and produces an attachable p10k zsh environment.

## Setup

Built an amd64 test image on an x86_64 NVIDIA Docker host, started a disposable GPU container with TTY and stdin enabled, and attached over SSH.

## Metrics

- Image build, PID 1 shell, real attach command execution, safe detach, GPU visibility, p10k gitstatus, CLI versions, credential refresh hook, LLM profiles, and research history startup.

## Results

All checks passed. PID 1 was zsh -il, the prompt rendered during docker attach, gitstatusd ran, an RTX 3090 was visible, the dynamic credential hook refreshed a dummy value, and the container remained running after detach.

## Artifacts

- Disposable image dolphin-validation:20260917161120 and matching container, both removed after validation.

## Interpretation / Next

Use the normal launcher with each server's local runtime.env.
