# Quick CRC Installation Fix

If you got this error:
```
Cloning into '/opt/homebrew/Library/Taps/codereadycontainers/homebrew-crc'...
remote: Repository not found.
```

The Homebrew tap has been deprecated. Use this method instead:

## Quick Fix: Direct Download

```bash
# 1. Download CRC installer
cd ~/Downloads
curl -LO https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/latest/crc-macos-installer.zip

# 2. Unzip and install
unzip crc-macos-installer.zip
sudo installer -pkg crc-macos-installer/crc.pkg -target /

# 3. Verify
crc version
```

That's it! Continue with the rest of the setup:
```bash
crc setup
crc start
```

## Alternative: Manual Binary Installation

If the installer doesn't work:

```bash
# Download binary
cd /tmp
curl -LO https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/latest/crc-macos-amd64-installer.zip

# Extract
unzip crc-macos-amd64-installer.zip

# Install to /usr/local/bin
sudo mv crc-macos-amd64-installer/crc /usr/local/bin/
sudo chmod +x /usr/local/bin/crc

# Verify
crc version
```

## For More Details

See [OPENSHIFT_INSTALLATION.md](OPENSHIFT_INSTALLATION.md) for comprehensive installation guide and troubleshooting.



