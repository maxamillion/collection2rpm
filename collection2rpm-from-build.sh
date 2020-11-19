#!/bin/bash

# Proof of concept shell script for collection2rpm

MOCK_CONF="${MOCK_CONF:-epel-8-x86_64}"

required_bins=(
    "/usr/bin/jq"
    "/usr/bin/rpmbuild"
    "/usr/bin/rpmdev-setuptree"
)

# sanity checking
if [[ -z ${1} ]]; then
    printf "ERROR: Must provide path to tarball of collection build with 'ansible-galaxy colleciton build' as input\n"
    exit 1
fi
for bin in ${required_bins[@]}; do
    if ! [[ -a "${bin}" ]]; then
        printf "ERROR: Depedency not found: %s\n" "${bin}"
    fi
done
COLLECTION_SRC_PATH="${1}"

work_dir=$(mktemp -d)
tarball_name=$(basename "${COLLECTION_SRC_PATH}")
cp "${COLLECTION_SRC_PATH}" "${work_dir}/"

pushd "${work_dir}" || return
    
    mkdir "./${tarball_name%-*}"
    tar -zxvf "./${tarball_name}" -C "./${tarball_name%-*}" 
    pushd "./${tarball_name%-*}"
        namespace=$(jq '.collection_info.namespace' MANIFEST.json)
        namespace="${namespace%\"}"
        namespace="${namespace#\"}"
        name=$(jq '.collection_info.name' MANIFEST.json)
        name="${name%\"}"
        name="${name#\"}"
        version=$(jq '.collection_info.version' MANIFEST.json)
        version="${version%\"}"
        version="${version#\"}"
        license=$(jq '.collection_info.license[0]' MANIFEST.json)
        license="${license%\"}"
        license="${license#\"}"
        description=$(jq '.collection_info.description' MANIFEST.json)
        description="${description%\"}"
        description="${description#\"}"
        repository=$(jq '.collection_info.repository' MANIFEST.json)
        repository="${repository%\"}"
        repository="${repository#\"}"
        readme=$(jq '.collection_info.readme' MANIFEST.json)
        readme="${readme%\"}"
        readme="${readme#\"}"
    popd
    mkdir -p "./${namespace}/${name}"
    cp -r ./"${tarball_name%-*}"/* "./${namespace}/${name}/"
    tar -cvzf "${namespace}-${name}-${version}.tar.gz" "${namespace}/${name}"
    rpmdev-setuptree
    mv "${namespace}-${name}-${version}.tar.gz" "${HOME}/rpmbuild/SOURCES/"
popd

cp "${COLLECTION_SRC_PATH}" "${HOME}/rpmbuild/SOURCES/" 

cat << EOF > "${HOME}/rpmbuild/SPECS/ansible-collection-${namespace}-${name}.spec"
Name: ansible-collection-${namespace}-${name}
Version: ${version}
Release: 1
Summary: Automatically generated RPM of the ${namespace}.${name} Ansible Collection
License: Unknown

URL: ${repository}
Source0: ${namespace}-${name}-${version}.tar.gz

%description
${description}

%prep
mkdir -p ${namespace}/${name}/
tar -xvzf %{SOURCE0} -C ${namespace}/${name}/
cd ${namespace}/${name}/

%build

%install
mkdir -p %{buildroot}/%{_datarootdir}/ansible/collections/ansible_collections/${namespace}/${name}
cp -r ./* %{buildroot}/%{_datarootdir}/ansible/collections/ansible_collections/${namespace}/${name}/

%files
%doc ${readme}
%license ${license}
%dir %{_datarootdir}/ansible/collections/ansible_collections/${namespace}/${name}

EOF

pushd "${HOME}/rpmbuild/SPECS/" || return
    #rpmbuild -bs "ansible-collection-${namespace}-${name}.spec"
    rpmbuild -bb "ansible-collection-${namespace}-${name}.spec"
popd
#mock -r "${MOCK_CONF}" "${HOME}/rpmbuild/SRPMS/ansible-collection-${namespace}-${name}-${version}-1.src.rpm"

# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

