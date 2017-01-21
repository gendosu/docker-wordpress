#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

phpVersions=( "$@" )
if [ ${#phpVersions[@]} -eq 0 ]; then
	phpVersions=( php*.*/ )
fi
phpVersions=( "${phpVersions[@]%/}" )

current="4.6.1"
sha1="c71ea0f6278ca9b2c49c6c5e4488a13a9e5e734b"
wordpressLang="ja"

declare -A variantExtras=(
	[apache]='\nRUN a2enmod rewrite expires\n'
	[fpm]=''
	[fpm-alpine]=''
)
declare -A variantCmds=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)
declare -A variantBases=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)

travisEnv=
for phpVersion in "${phpVersions[@]}"; do
	phpVersionDir="$phpVersion"
	phpVersion="${phpVersion#php}"

	for variant in apache fpm fpm-alpine; do
		dir="$phpVersionDir/$variant"
		mkdir -p "$dir"

		extras="${variantExtras[$variant]}"
		cmd="${variantCmds[$variant]}"
		base="${variantBases[$variant]}"

		(
			set -x

			sed -r \
				-e 's!%%WORDPRESS_VERSION%%!'"$current"'!g' \
				-e 's!%%WORDPRESS_SHA1%%!'"$sha1"'!g' \
				-e 's!%%WORDPRESS_LANG%%!'"$wordpressLang"'!g' \
				-e 's!%%WORDPRESS_SUBDOMAIN%%!'"${wordpressLang}."'!g' \
				-e 's!%%WORDPRESS_SUFFIX%%!'"-${wordpressLang}"'!g' \
				-e 's!%%PHP_VERSION%%!'"$phpVersion"'!g' \
				-e 's!%%VARIANT%%!'"$variant"'!g' \
				-e 's!%%VARIANT_EXTRAS%%!'"$extras"'!g' \
				-e 's!%%CMD%%!'"$cmd"'!g' \
				"Dockerfile-${base}.template" > "$dir/Dockerfile"

			cp docker-entrypoint.sh "$dir/docker-entrypoint.sh"
		)

		travisEnv+='\n  - VARIANT='"$dir"
	done
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
