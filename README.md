# Hedera Peer-to-Peer Data Sharing

Download Hedera mainnet data for free via P2P networks—no AWS or GCP required. Import and validate data directly into your own mirror node.

## Quick Start

1. **Download** a torrent file from the [torrent](./torrent) folder (one per year)
2. **Open** with any BitTorrent client (qBittorrent, Transmission, etc.)
3. **Extract** the tar archives to your mirror node data directory
4. **Configure** your mirror node to import from the local filesystem

## Available Torrents

| Year | Size | Torrent File | Magnet File 🧲 |
|:----:|-----:|:------------:|:-----------:|
| 2019 | 13.65 GiB | [Download](./torrent/hedera-hashgraph-signatures-records-sidecars-2019.torrent) | [Magnet](./torrent/hedera-hashgraph-signatures-records-sidecars-2019.magnet) |
| 2020 | 224.63 GiB | [Download](./torrent/hedera-hashgraph-signatures-records-sidecars-2020.torrent) | [Magnet](./torrent/hedera-hashgraph-signatures-records-sidecars-2020.magnet) |
| 2021 | 817.77 GiB | [Download](./torrent/hedera-hashgraph-signatures-records-sidecars-2021.torrent) | [Magnet](./torrent/hedera-hashgraph-signatures-records-sidecars-2021.magnet) |
| 2022 | 420.46 GiB | [Download](./torrent/hedera-hashgraph-signatures-records-sidecars-2022.torrent) | [Magnet](./torrent/hedera-hashgraph-signatures-records-sidecars-2022.magnet) |
| 2023 | 7.72 TiB | [Download](./torrent/hedera-hashgraph-signatures-records-sidecars-2023.torrent) | [Magnet](./torrent/hedera-hashgraph-signatures-records-sidecars-2023.magnet) |
| 2024 | 7.78 TiB | [Download](./torrent/hedera-hashgraph-signatures-records-sidecars-2024.torrent) | [Magnet](./torrent/hedera-hashgraph-signatures-records-sidecars-2024.magnet) |
| 2025 | 206.86 GiB | [Download](./torrent/hedera-hashgraph-signatures-records-sidecars-2025.torrent) | [Magnet](./torrent/hedera-hashgraph-signatures-records-sidecars-2025.magnet) |

> **Note:** Data starts from September 13, 2019 although the Hedera mainnet public open access was [officially announced and formalized](https://hedera.com/blog/decentralized-applications-go-live-on-hedera-hashgraph-as-mainnet-opens-to-public) on September 16, 2019.

## IPFS Sharing (TODO)

I'm planning to make Hedera data available via IPFS as well. Stay tuned.

## How to Contribute

Help decentralize Hedera data distribution:

- **Seed torrents** — Keep your client running after download
- **Share via IPFS** — Help expand to other P2P networks (coming soon)
- **Run a tracker** — Host a BitTorrent tracker for better peer discovery
- **Build tools** — Improve the Mirror Node to support P2P download and sharing. Suggest tools to improve the managements and filer of terabytes of data.

## Future Plans

- Automated torrent generation for new data (archive generation is already automated)
- Create a website describing the project and how to contribute
- Integration with Mirror Node for direct P2P import
- Block node compatibility (when available)

## Data Structure

Each torrent contains **two files per day**:

| File | Description |
|------|-------------|
| `YYYY-MM-DD.records.tar.xz/gz` | Record files + sidecars |
| `YYYY-MM-DD.signatures.tar.xz` | Consensus signatures (⅓+1 nodes) |

### Extraction

Files are designed to be extracted into the same directory without conflicts:

```bash
# Extract all files in parallel (-P is adjusted to your CPU cores)
ls *.tar.xz | xargs -P $(nproc --all) -I {} tar -xf {} -C /path/to/mirror-node/data/
ls *.tar.gz | xargs -P $(nproc --all) -I {} tar -xf {} -C /path/to/mirror-node/data/
```

Each day creates its own `YYYY-MM-DD/` folder with records and signatures in the correct subfolders.

### Compression Format

| Period | Records | Signatures |
|--------|---------|------------|
| Sep 2019 – May 27, 2022 | `.tar.xz` | `.tar.xz` |
| May 28, 2022 – present | `.tar.gz` | `.tar.xz` |

> Records switched to gzip because consensus nodes started outputting pre-compressed files.

## How files are created (TODO)

In this repo you can find also all the scripts and configurations I used for historical data and those I use now to keep up with the data. I'll publish more details soon.
