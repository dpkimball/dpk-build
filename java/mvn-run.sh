#!/bin/bash
# Shared Maven runner for java/*.sh — local mvn or Docker Maven.
# shellcheck shell=bash

resolve_maven_pom() {
  if [[ -n "${MAVEN_POM:-}" ]]; then
    echo "$MAVEN_POM"
    return 0
  fi
  if [[ -f pom.xml ]]; then
    echo "pom.xml"
    return 0
  fi
  if [[ -f jobs/pom.xml ]]; then
    echo "jobs/pom.xml"
    return 0
  fi
  echo "ERROR: no pom.xml or jobs/pom.xml found (set MAVEN_POM)" >&2
  return 1
}

run_maven() {
  local pom
  pom="$(resolve_maven_pom)"
  if command -v mvn >/dev/null 2>&1; then
    mvn -B -f "$pom" "$@"
    return $?
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: neither mvn nor docker found on PATH" >&2
    return 1
  fi
  local image="${MAVEN_IMAGE:-maven:3.9-eclipse-temurin-17}"
  local project_dir
  project_dir="$(pwd)"
  mkdir -p "${HOME}/.m2"
  docker run --rm \
    -v "${project_dir}:/workspace" \
    -v "${HOME}/.m2:/root/.m2" \
    -w /workspace \
    "$image" \
    mvn -B -f "$pom" "$@"
}
