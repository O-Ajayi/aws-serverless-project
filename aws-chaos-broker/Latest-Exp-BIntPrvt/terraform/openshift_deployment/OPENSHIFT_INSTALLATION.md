# CRC Installation Guide - Updated 2024/2025

The CodeReady Containers (CRC) Homebrew tap has been deprecated. This guide provides updated installation methods.

## Installation Methods

### Method 1: Direct Download and Install (Recommended)

This is the most reliable method:

1. **Download CRC Installer**
   - Visit: https://developers.redhat.com/products/openshift-local/download
   - Or download directly:
     ```bash
     cd ~/Downloads
     curl -LO https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/latest/crc-macos-installer.zip
     ```

2. **Install CRC**
   ```bash
   # Unzip the installer
   unzip crc-macos-installer.zip
   
   # Install the package
   sudo installer -pkg crc-macos-installer/crc.pkg -target /
   ```

3. **Verify Installation**
   ```bash
   crc version
   ```

### Method 2: Manual Binary Installation

If you prefer to install the binary directly:

```bash
# Download CRC binary
cd /tmp
curl -LO https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/latest/crc-macos-amd64-installer.zip

# Unzip
unzip crc-macos-amd64-installer.zip

# Move to /usr/local/bin
sudo mv crc-macos-amd64-installer/crc /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/crc

# Verify
crc version
```

### Method 3: Homebrew (May Not Work)

The old tap `codereadycontainers/crc/crc` is deprecated. Try these alternatives:

```bash
# Option A: Try new tap (if available)
brew tap redhat-developer/redhat-developer
brew install crc

# Option B: Try cask
brew install --cask crc

# Option C: If above fails, use Method 1 or 2
```

### Method 4: Using MacPorts (Alternative)

If you use MacPorts:

```bash
sudo port install crc
```

## Verification

After installation, verify CRC is working:

```bash
# Check version
crc version

# Should output something like:
# CodeReady Containers version: 2.x.x+xxxxx
# OpenShift version: 4.x.x
```

## Troubleshooting

### "Command not found: crc"

If `crc` command is not found after installation:

```bash
# Check if it's in a non-standard location
which crc

# Add to PATH if needed
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Or for bash
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
```

### Homebrew Installation Errors

If Homebrew methods fail:

1. **Use Method 1 (Direct Download)** - Most reliable
2. **Check Homebrew tap**: The repository may have moved or been deprecated
3. **Manual installation** is always available as fallback

### Permission Issues

If you get permission errors:

```bash
# Make sure crc is executable
sudo chmod +x /usr/local/bin/crc

# Or if installed elsewhere
sudo chmod +x $(which crc)
```

## Next Steps

After successfully installing CRC:

1. Continue with setup:
   ```bash
   crc setup
   crc start
   ```

2. Or use the automated setup script:
   ```bash
   cd terraform/openshift_deployment
   ./scripts/setup-crc.sh
   ```

## Additional Resources

- **Official CRC Documentation**: https://crc.dev/crc/
- **Download Page**: https://developers.redhat.com/products/openshift-local/download
- **Red Hat Developer Portal**: https://developers.redhat.com/

## Note on Name Change

CRC (CodeReady Containers) has been renamed to **Red Hat OpenShift Local**, but the command-line tool is still called `crc`. When searching for documentation or downloads, you may see either name.


