#!/bin/bash

# Proof of concept shell script for collection2rpm

COLLECTION_NAME="${COLLECTION_NAME:-ansible.posix}"
MOCK_CONF="${MOCK_CONF:-epel-8-x86_64}"

namespace="${COLLECTION_NAME%\.*}"
name="${COLLECTION_NAME#*\.}"

work_dir="${PWD}"

install_line=$(ansible-galaxy collection install -p ./collections "${COLLECTION_NAME}" -f | grep "${COLLECTION_NAME}")

version_tmp="${install_line#*${COLLECTION_NAME}:}"
version="${version_tmp%%\'*}"

rpmdev-setuptree
pushd "./collections/ansible_collections/" || return
    tar -cvzf "${namespace}-${name}-${version}.tar.gz" "${namespace}/${name}"
    mv "${namespace}-${name}-${version}.tar.gz" "${HOME}/rpmbuild/SOURCES/" 
popd

cat << EOF > "${HOME}/rpmbuild/SPECS/ansible-collection-${namespace}-${name}.spec"
Name: ansible-collection-${namespace}-${name}
Version: ${version}
Release: 1
Summary: Automatically generated RPM of the ${namespace}.${name} Ansible Collection
License: Unknown

Source0: ${namespace}-${name}-${version}.tar.gz

%description

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}/%{_datarootdir}/ansible/collections/ansible_collections/${namespace}/${name}
cp -r ./* %{buildroot}/%{_datarootdir}/ansible/collections/ansible_collections/${namespace}/${name}/

%files
%dir %{_datarootdir}/ansible/collections/ansible_collections/${namespace}/${name}

EOF

pushd "${HOME}/rpmbuild/SPECS/" || return
    rpmbuild -bs "ansible-collection-${namespace}-${name}.spec"
popd
mock -r "${MOCK_CONF}" "${HOME}/rpmbuild/SRPMS/ansible-collection-${namespace}-${name}-${version}-1.src.rpm"

# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

