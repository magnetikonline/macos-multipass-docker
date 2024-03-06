#!/bin/bash -e

BIN_DIR="/usr/local/bin"
ARCH=$(uname -m)
ARCH_ARCH="x86_64"
if [[ $ARCH == "arm64" ]]; then
	ARCH_ARCH="aarch64"
fi


function main {
	if [[ ! -x $(command -v jq) ]]; then
		echo "Error: expecting to find jq" >&2
		exit 1
	fi

	# install docker CLI
	local latest=$(curl --silent "https://api.github.com/repos/docker/cli/tags" | \
		jq --raw-output \
			'[.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name] | first'
	)

	local archivePath=$(mktemp -d)
	curl --location --silent \
		"https://download.docker.com/mac/static/stable/$ARCH_ARCH/docker-${latest#v}.tgz" | \
			tar --directory "$archivePath" --extract --gzip

	sudo mv "$archivePath/docker/docker" "$BIN_DIR"
	sudo chown root: "$BIN_DIR/docker"
	docker --version

	if [[ -d /usr/local/etc/bash_completion.d ]]; then
		# bash completion
		sudo curl \
			--location \
			--output /usr/local/etc/bash_completion.d/docker \
			--silent \
				"https://raw.githubusercontent.com/docker/cli/$latest/contrib/completion/bash/docker"
	fi

	# install docker-compose CLI plugin
	local dockerPluginDir="$HOME/.docker/cli-plugins"
	mkdir -p "$dockerPluginDir"

	local dockerComposePlugin="$dockerPluginDir/docker-compose"
	local latest=$(curl --silent "https://api.github.com/repos/docker/compose/releases" | \
		jq --raw-output \
			'[.[] | select(.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .tag_name] | first'
	)

	rm -f "$dockerComposePlugin"
	curl \
		--location \
		--output "$dockerComposePlugin" \
		--silent \
			"https://github.com/docker/compose/releases/download/$latest/docker-compose-darwin-$ARCH_ARCH"

	chmod u+x "$dockerComposePlugin"
	xattr -dr com.apple.quarantine "$dockerComposePlugin"
	echo -e '#!/bin/bash -e\n\ndocker compose --compatibility "$@"' | sudo tee "$BIN_DIR/docker-compose" >/dev/null
	sudo chmod +x "$BIN_DIR/docker-compose"
	docker-compose version
}


main
