#!/usr/bin/env python3
"""
Discord Bot for DevOps Pipeline Control
Provides slash commands to trigger GitHub Actions workflows
"""

import os
import discord
from discord import app_commands
import aiohttp
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('devops-bot')

# Environment variables
DISCORD_TOKEN = os.getenv('DISCORD_BOT_TOKEN')
DISCORD_GUILD_ID = os.getenv('DISCORD_GUILD_ID')
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
GIT_REPO = os.getenv('GIT_REPO')  # Format: owner/repo

if not all([DISCORD_TOKEN, DISCORD_GUILD_ID, GITHUB_TOKEN, GIT_REPO]):
    logger.error("Missing required environment variables!")
    exit(1)

# Discord client setup
intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)

class GitHubAPI:
    """GitHub API wrapper for workflow dispatch"""
    
    BASE_URL = "https://api.github.com"
    
    def __init__(self, token: str, repo: str):
        self.token = token
        self.repo = repo
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28"
        }
    
    async def trigger_workflow(self, workflow_file: str, action: str) -> dict:
        """Trigger a GitHub Actions workflow"""
        url = f"{self.BASE_URL}/repos/{self.repo}/actions/workflows/{workflow_file}/dispatches"
        
        payload = {
            "ref": "main",
            "inputs": {
                "action": action
            }
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=self.headers, json=payload) as response:
                if response.status == 204:
                    return {"success": True, "message": "Workflow triggered successfully"}
                else:
                    error_text = await response.text()
                    return {"success": False, "message": f"Failed: {error_text}"}

# Initialize GitHub API
github = GitHubAPI(GITHUB_TOKEN, GIT_REPO)

@client.event
async def on_ready():
    """Bot startup event"""
    logger.info(f'Logged in as {client.user}')
    
    # Sync commands to guild
    guild = discord.Object(id=int(DISCORD_GUILD_ID))
    tree.copy_global_to(guild=guild)
    await tree.sync(guild=guild)
    logger.info(f'Commands synced to guild {DISCORD_GUILD_ID}')

@tree.command(
    name="deploy",
    description="🚀 Deploy infrastructure to AWS"
)
async def deploy(interaction: discord.Interaction):
    """Deploy infrastructure via GitHub Actions"""
    await interaction.response.defer(thinking=True)
    
    result = await github.trigger_workflow("infra-makefile.yml", "deploy")
    
    embed = discord.Embed(
        title="🚀 Deployment Triggered" if result["success"] else "❌ Deployment Failed",
        description=result["message"],
        color=discord.Color.green() if result["success"] else discord.Color.red(),
        timestamp=datetime.utcnow()
    )
    embed.add_field(name="Triggered by", value=interaction.user.mention, inline=True)
    embed.add_field(name="Action", value="deploy", inline=True)
    embed.set_footer(text=f"GitHub Actions • {GIT_REPO}")
    
    await interaction.followup.send(embed=embed)
    logger.info(f"Deploy triggered by {interaction.user.name}")

@tree.command(
    name="destroy",
    description="💥 Destroy AWS infrastructure (use with caution!)"
)
async def destroy(interaction: discord.Interaction):
    """Destroy infrastructure via GitHub Actions"""
    await interaction.response.defer(thinking=True)
    
    result = await github.trigger_workflow("infra-makefile.yml", "destroy")
    
    embed = discord.Embed(
        title="💥 Destruction Triggered" if result["success"] else "❌ Destruction Failed",
        description=result["message"],
        color=discord.Color.orange() if result["success"] else discord.Color.red(),
        timestamp=datetime.utcnow()
    )
    embed.add_field(name="Triggered by", value=interaction.user.mention, inline=True)
    embed.add_field(name="Action", value="destroy", inline=True)
    embed.add_field(name="⚠️ Warning", value="Infrastructure will be destroyed!", inline=False)
    embed.set_footer(text=f"GitHub Actions • {GIT_REPO}")
    
    await interaction.followup.send(embed=embed)
    logger.warning(f"Destroy triggered by {interaction.user.name}")

@tree.command(
    name="status",
    description="📊 Check infrastructure status"
)
async def status(interaction: discord.Interaction):
    """Check infrastructure status via GitHub Actions"""
    await interaction.response.defer(thinking=True)
    
    result = await github.trigger_workflow("infra-makefile.yml", "check-status")
    
    embed = discord.Embed(
        title="📊 Status Check Triggered" if result["success"] else "❌ Status Check Failed",
        description=result["message"],
        color=discord.Color.blue() if result["success"] else discord.Color.red(),
        timestamp=datetime.utcnow()
    )
    embed.add_field(name="Triggered by", value=interaction.user.mention, inline=True)
    embed.add_field(name="Action", value="check-status", inline=True)
    embed.add_field(name="ℹ️ Info", value="Status will be posted to webhook channel", inline=False)
    embed.set_footer(text=f"GitHub Actions • {GIT_REPO}")
    
    await interaction.followup.send(embed=embed)
    logger.info(f"Status check triggered by {interaction.user.name}")

@tree.command(
    name="help",
    description="📖 Show available commands"
)
async def help_command(interaction: discord.Interaction):
    """Show help information"""
    embed = discord.Embed(
        title="📖 DevOps Bot Commands",
        description="Available commands for managing your infrastructure",
        color=discord.Color.purple(),
        timestamp=datetime.utcnow()
    )
    
    embed.add_field(
        name="/deploy",
        value="🚀 Deploy infrastructure to AWS",
        inline=False
    )
    embed.add_field(
        name="/destroy",
        value="💥 Destroy AWS infrastructure (use with caution!)",
        inline=False
    )
    embed.add_field(
        name="/status",
        value="📊 Check current infrastructure status",
        inline=False
    )
    embed.add_field(
        name="/help",
        value="📖 Show this help message",
        inline=False
    )
    
    embed.set_footer(text=f"GitHub Actions • {GIT_REPO}")
    
    await interaction.response.send_message(embed=embed)

# Run the bot
if __name__ == "__main__":
    try:
        client.run(DISCORD_TOKEN)
    except Exception as e:
        logger.error(f"Failed to start bot: {e}")
        exit(1)
