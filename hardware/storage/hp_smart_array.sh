echo 'deb http://downloads.linux.hpe.com/SDR/repo/mcp xenial/current non-free' | sudo tee /etc/apt/sources.list.d/hp.list
sudo apt-get update
sudo apt-get install hpacucli
