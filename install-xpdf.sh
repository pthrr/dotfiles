sudo mkdir ~/bin ~/opt ~/tmp
cd ~/tmp
sudo wget http://security.ubuntu.com/ubuntu/pool/main/p/poppler/libpoppler73_0.62.0-2ubuntu2.12_amd64.deb
sudo apt-get install -y ./libpoppler73_0.62.0-2ubuntu2.12_amd64.deb
sudo wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xpdf/xpdf_3.04-7_amd64.deb
sudo apt-get install -y ./xpdf_3.04-7_amd64.deb
