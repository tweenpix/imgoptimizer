# imgoptimizer
Optimize images via Squoosh

- optimize jpg
- optimize png
- optimize svg
- convert bmp to jpg
- convert jpg, png to webp + avif
- check for avoid double optimization

# Requirements
for running need installed node.js + sharp (https://www.npmjs.com/package/sharp)

# Installation
First of first, need install NODE.JS

## 1. Node.js for Ubuntu    
sudo curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -    
sudo apt-get install -y nodejs    

## 1. Node.js for Debian, as root    
sudo curl -fsSL https://deb.nodesource.com/setup_20.x | bash -    
sudo apt-get install -y nodejs    

## 2. download imgoptimize.js
git clone https://github.com/tweenpix/imgoptimizer.git

## 3. Make link to USR/LOCAL/BIN
chmod +x /path/to/imgoptimize.js
ln -s /path/to/imgoptimize.js /usr/local/bin/imgoptimize

## 4. Change file user owner and path to log file in imgoptimize.js
``
const logFile = "/var/log/optimization.log";
``
``
const iUser = 'webuser';
``
``
const iGroup = 'webuser';
``

# Running
run from parrent image directory for recursivly optimization    
as    
find . -type d \( ! -name . \) -exec bash -c "cd '{}' && imgoptimize" \;

# Clean result
just run: imgoptimize clean


## Example
# ![https://imgur.com/gallery/ytHTvaK](https://i.imgur.com/P7yF4uc.png)
