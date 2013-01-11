Summary:    BIOS update package download tool
Name:       bios-downloader
Version:    0.1
Release:    git%{?dist}
Epoch:      %(date +%s)
License:    GPLv2+
Group:      Applications/System
BuildArch:  noarch

Requires:	curl
Requires:	xmlstarlet
Requires:	tidy
Requires:	python

URL:		https://github.com/YKonovalov/bios-downloader
BuildRoot:	%_tmppath/%name-%version-root

Source0: %name-%version.tar.gz

%description
This tools can simplify or automate the task of getting main
system firmware update packages from official vendor's
download sites.

%prep
%setup

%build
make distpath

%install
[ %buildroot = "/" ] || rm -rf %buildroot
make DESTDIR=%buildroot install

%clean
[ %buildroot = "/" ] || rm -rf %buildroot

%files
%_bindir/*
%_datadir/%name/modules/*

%changelog
* Tue Jan 12 2012 Yury Konovalov <YKonovalov@gmail.com> - 0.1
- Initial spec.
