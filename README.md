mediatomb
=========

My configs and scripts for MediaTomb server

### Prerequisites

* ffmpeg
* mencoder
* lsdvd
* mediainfo
* ttf-freefont
* ttf-dejavu-core
* fontconfig
* xmlstarlet

### Installation

Put (or symlink) this project to _/usr/local/mediatomb_

Install prerequisites. Install string for Ubuntu 12.04 is:

> sudo apt-get install ffmpeg mencoder lsdvd mediainfo xmlstarlet ttf-freefont ttf-dejavu-core fontconfig

Symlink mediatomb config file to this project location:

> sudo ln -s /usr/local/mediatomb/etc/config.xml /etc/mediatomb/config.xml

