# Dev/CI image for the NFE.io Ruby SDK.
#
# The Ruby version is set at build time (default 3.4 = the dev .ruby-version;
# the supported floor is 3.2). The full `ruby` image (not slim/alpine) is used
# so native extensions — e.g. the rbs parser — compile without extra apt work.
ARG RUBY_VERSION=3.4
FROM ruby:${RUBY_VERSION}

# git: used by bundler git sources and rake. build tools ship in the full image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Non-root user matching the host UID/GID so files written through the bind
# mount (Gemfile.lock, coverage/) stay owned by the developer, not root.
ARG UID=1000
ARG GID=1000
RUN (getent group "${GID}" || groupadd --system --gid "${GID}" app) \
    && (getent passwd "${UID}" || useradd --uid "${UID}" --gid "${GID}" --create-home --shell /bin/bash app)

# Bundler installs into a cached, user-owned path (a named volume in compose),
# namespaced by Ruby ABI so 3.2/3.3/3.4 can share the same volume safely.
ENV BUNDLE_PATH=/home/app/bundle \
    BUNDLE_APP_CONFIG=/home/app/bundle \
    BUNDLE_JOBS=4
RUN mkdir -p /home/app/bundle && chown -R "${UID}:${GID}" /home/app

USER ${UID}:${GID}
WORKDIR /app

CMD ["ruby", "-v"]
