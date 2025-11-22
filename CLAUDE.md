# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains research, analysis, and infrastructure for text-to-video AI models, focused on professional video production using self-hosted solutions on AWS. The primary analysis compares models like HoloCine-14B, HunyuanVideo, and Wan 2.2 against commercial alternatives like OpenAI Sora.

## Infrastructure Status

**⏳ Waiting for AWS quota approval**
- Requested: 96 vCPUs for G and VT instances (us-east-2)
- Target: G5.12xlarge (4x NVIDIA A10G, 96GB VRAM)
- When approved: run `terraform apply` in `/terraform` directory
- See: `terraform/README.md` for complete setup instructions

## Repository Structure

```
revalida-video-generator/
├── terraform/               # AWS infrastructure as code
│   ├── README.md           # Setup instructions and troubleshooting
│   ├── *.tf                # Terraform configuration files
│   ├── terraform.tfvars    # Configuration variables (gitignored)
│   ├── terraform.tfvars.example  # Template for configuration
│   └── ansible.tf          # Ansible integration
├── ansible/                 # Server configuration automation
│   ├── README.md           # Ansible documentation
│   ├── playbook.yml        # Main setup playbook
│   ├── inventory.tpl       # Inventory template (for Terraform)
│   ├── inventory.yml       # Generated inventory (gitignored)
│   └── files/
│       └── bashrc-additions.sh  # Bash aliases and helpers
├── docs/
│   └── analise-modelos-text-to-video.md  # Comprehensive analysis document (Portuguese)
├── .gitignore              # Protects sensitive data
└── CLAUDE.md               # This file
```

## Document Architecture

The main analysis document (`analise-modelos-text-to-video.md`) is structured as:

1. **Executive Summary & TL;DR** - Quick decision-making information with cost comparisons
2. **Model Comparative Analysis** - Detailed technical specifications, VRAM requirements, quality ratings
3. **Top 3 Recommended Models**:
   - HoloCine-14B: Multi-shot narratives with consistent characters
   - HunyuanVideo + LoRA: Best visual quality (720p native, 30 FPS)
   - Wan 2.2: Best versatility
4. **AWS Cost Analysis** - Instance configurations (G5.12xlarge), Spot vs On-Demand pricing
5. **Production Setup Guide** - Complete installation and deployment instructions
6. **Use Case Recommendations** - Scenario-based model selection
7. **Implementation Plan** - Phased rollout strategy
8. **Commercial Comparisons** - ROI analysis vs Sora, Runway, Pika Labs
9. **FAQ Section** - 12 common questions with detailed answers
10. **Resources & Conclusion** - Links to GitHub repos, papers, tools

## Key Technical Concepts

### Models Analyzed

- **HoloCine-14B**: Only model with native multi-shot support (up to 60s), Window Cross-Attention architecture
- **HunyuanVideo**: 13B parameters, 3D Causal VAE, supports LoRA training for character consistency
- **Wan 2.2**: MoE (Mixture-of-Experts) architecture, supports both T2V and I2V
- **CogVideoX-5B, Mochi-1, LTX-Video**: Alternative models with various trade-offs

### AWS Infrastructure

- **Primary Instance**: G5.12xlarge (4x NVIDIA A10G, 96GB VRAM total)
- **Pricing Strategy**: Spot instances (~$1.70/hour, 70% savings vs On-Demand)
- **Cost Efficiency**: $0.28-0.42 per video vs $6-30 for Sora (93-98% cheaper)
- **Production Capacity**: 4-6 videos/hour (96-144 videos/day)

### Character Consistency Approaches

1. **HoloCine**: Native multi-shot with Sparse Inter-Shot Self-Attention
2. **HunyuanVideo**: LoRA training workflow (generate 30 reference images → train LoRA → apply to all videos)
3. **Others**: Workarounds with limited reliability

## Document Maintenance Guidelines

### When Updating Analysis

1. **Model Specifications**: Update tables when new models are released or specs change
2. **AWS Pricing**: Verify G5 instance prices quarterly (Spot prices fluctuate)
3. **Benchmark Scores**: Add new comparative benchmarks when available
4. **Commercial Comparisons**: Update Sora/Runway/Pika pricing when APIs change

### Document Language

The analysis is written in **Portuguese (Brazilian)** for the target audience. Maintain this language when adding content or making updates.

### Version Control

- Document includes changelog at the bottom
- Use semantic versioning (e.g., v2.1)
- Document major changes: model additions, pricing updates, new setup procedures

## Common Tasks

### Adding a New Model Analysis

1. Add to comparison table in Section 1.1 (specifications)
2. Add quality ratings in Section 1.2
3. Add character consistency evaluation in Section 1.3
4. If top-tier, create detailed section in Section 2
5. Update cost analysis in Section 3.2
6. Update recommendations in Section 5
7. Update changelog at bottom

### Updating AWS Pricing

1. Verify current prices at https://aws.amazon.com/ec2/spot/pricing/
2. Update Section 3.1 (instance specs and pricing)
3. Recalculate cost per video in Section 3.2
4. Update ROI calculations in Section 7.3
5. Update TL;DR section with new economics

### Adding Setup Instructions

1. Add to Section 4 (Setup AWS para Produção)
2. Include complete bash commands
3. Specify directory structure
4. List exact checkpoint download locations
5. Document VRAM requirements clearly

## Technical Dependencies Referenced

- **CUDA 12.1+**: Required for all production models
- **FlashAttention-3**: Recommended for HoloCine (FlashAttention-2 as fallback)
- **PyTorch 2.4+**: Base framework
- **ComfyUI**: GUI workflow integration
- **Diffusers (Hugging Face)**: Model loading and inference
- **FFmpeg**: Video post-processing

## Important Links Structure

Links are organized by category:
- GitHub repositories (model source code)
- Hugging Face (model weights and papers)
- AWS documentation (instance types, AMIs)
- Tool repositories (ComfyUI, LoRA training, upscalers)

Always use official/canonical URLs to avoid broken links.

## Cost Analysis Methodology

All cost calculations use:
- **AWS G5.12xlarge Spot pricing**: $1.70/hour baseline
- **Generation time estimates**: Conservative (actual may be faster)
- **Commercial API pricing**: Current public rates at time of writing
- **ROI calculations**: Based on $5-30/video pricing for end customers

When updating costs, maintain consistency across all sections (1, 3, 5, 7, 8).

## Multi-Shot vs Single-Shot Context

This is a critical architectural distinction in the analysis:

- **Multi-shot**: Single generation produces multiple camera angles/scenes with consistent characters (HoloCine only)
- **Single-shot**: Each generation is one continuous scene
- **Workaround approach**: Generate multiple single-shots and manually ensure consistency via LoRA

This distinction drives model selection recommendations throughout the document.
