#!/usr/bin/env bash

if [[ ${#} -ne 1 ]]; then
	echo "Invalid number of arguments, Usage: log-to-licenses <log file>"
	exit 1
fi

if ! command -v qfile > /dev/null; then
	echo "Command qfile not found, please install app-portage/portage-utils"
	exit 1
fi

if ! command -v eix > /dev/null; then
	echo "Command eix not found, please install app-portage/eix"
	exit 1
fi

log_file=${1}

unknown=()
out=()

while read -r line; do
	if [[ -d ${line} ]]; then
		echo "${line} is a directory"
		continue
	fi

	if [[ ! -f ${line} ]]; then
		unknown+=( ${line} )
		continue
	fi

	realpath=$(realpath "${line}")
	# Dracut sometimes moves /sbin/ files into /bin/ of the initrd
	sbin_opt=${line//bin/sbin}
	# Try several options to accommodate for merged-usr and symlinks
	for try in \
		"${realpath}" "/usr${realpath}" "${realpath//\/usr/}" \
		"${line}" "/usr${line}" "${line//\/usr/}" \
		"${sbin_opt}" "/usr${sbin_opt}" "${sbin_opt//\/usr/}"
	do
		owner=$(qfile -q "${try}")
		if [[ ${owner} ]]; then
			line=${try}
			break
		fi
	done

	if [[ ${owner} ]]; then
		owner_licenses=$(eix -I -e --format '<licenses>\n' ${owner})
		echo "${line} is owned by ${owner} which has licenses ${owner_licenses}"
		out+=( "[\"${owner}\"]=\"${owner_licenses}\"" )
	else
		echo "${line} has no known owner"
		unknown+=( ${line} )
	fi

done < <( sed -n -e 's/^dracut\[D\]:.*root     root.*:[0-9][0-9] /\//gp' "${log_file}" | sed -e 's/\ ->.*$//g')

IFS=$'\n' sorted=($(sort -u <<<"${out[*]}"))

echo
echo "Generated dependency and license array:"
echo "${sorted[*]}"
echo
echo "Unknown files:"
echo "${unknown[*]}"
echo
