# Copyright 2018 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# This is a sample Dockerfile for packaging an Elixir application
# as a Docker image. It builds a Distillery release and installs it on
# Alpine Linux. The final image launches the application on an ENV
# configurable port (eg: 8080).
#
# This Dockerfile includes two stages and requires Docker 17.05 or later.
#
# To adapt this Dockerfile to your app, set the APP_NAME and APP_SUBDIR
# build arguments, as outlined below.


################################################################################
# BUILD STAGE
#
# Builds the app, does a Brunch build to build the assets, and creates a
# release. This stage uses the official Alpine Linux - Elixir base image
FROM elixir:alpine

##############################################################################
# BUILD ARGUMENTS
#
# Modify these to adapt this Dockerfile to your app.
# These configure the Docker build process, not necissarily the app.
# Alternatively, you may specify --build-arg when running `docker build`.
# The name of your Elixir application.
ARG APP_NAME=house_party

# The subdirectory of the Elixir application within the toplevel project.
# If your project is an umbrella project, this should be the relative path
# to the Elixir application, e.g. "apps/hello_web". If this is a simple
# project, this should be "."
ARG APP_SUBDIR=.

##############################################################################
# ENVIRONMENT VARIABLES
#
# Set up build environment, with ENV variables.
ENV MIX_ENV=prod \
    REPLACE_OS_VARS=true \
    TERM=xterm

# Set the build directory.
WORKDIR /opt/app

# setup local hex & rebar
RUN mix local.hex --force
RUN mix local.rebar --force

# Copy the application files into /opt/app.
COPY . .

# Build the application.
RUN mix do deps.get, deps.compile, compile

# Create the release, and move the artifacts to well-known paths so the
# runtime image doesn't need to know the app name. Specifically, the binary
# is renamed to "start_server", and the entire release is moved into
# /opt/release.
RUN mix release --env=prod --verbose \
    && mv _build/prod/rel/${APP_NAME} /opt/release \
    && mv /opt/release/bin/${APP_NAME} /opt/release/bin/start_server


################################################################################
# RUNTIME STAGE
#
# Creates the actual runtime image. This is based on a the Alpine Linux base
# image, with only the minimum dependencies for running ERTS.

FROM alpine:latest

# Install dependencies for ERTS.
RUN apk update \
    && apk --no-cache --update add bash openssl-dev

##############################################################################
# ENVIRONMENT VARIABLES
#
# These configure the app, at runtime.
# These ENV variables are always set, but you can change at container runtime.
ENV PORT=8080 \
    MIX_ENV=prod \
    REPLACE_OS_VARS=true

# Set the install directory. The app will run from here.
WORKDIR /opt/app

# Obtain the built application release from the build stage.
COPY --from=0 /opt/release .

# Start the server.
EXPOSE ${PORT}
CMD ["/opt/app/bin/start_server", "foreground"]
