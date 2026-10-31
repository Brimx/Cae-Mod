function cc-or --description "Claude Code con OpenRouter (~/.claude/providers/openrouter.json)"
    set -l claude_bin (command -s claude)
    env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY \
        -u ANTHROPIC_MODEL -u ANTHROPIC_DEFAULT_OPUS_MODEL \
        -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
        $claude_bin --setting-sources project,local \
        --settings ~/.claude/providers/openrouter.json $argv
end
