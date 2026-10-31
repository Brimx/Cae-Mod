function claude --description "Claude Code: elegir proveedor antes de iniciar"
    echo "Proveedor para esta sesión:"
    echo "  1) Anthropic (OAuth / cuenta Claude)"
    echo "  2) Token Harbor"
    echo "  3) OpenRouter"
    read -P "Elige [1-3]: " provider
    set -l claude_bin (command -s claude)

    switch "$provider"
        case 1
            env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY \
                -u ANTHROPIC_MODEL -u ANTHROPIC_DEFAULT_OPUS_MODEL \
                -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
                $claude_bin --setting-sources project,local \
                --settings ~/.claude/providers/anthropic.json $argv
        case 2
            cc-th $argv
        case 3
            cc-or $argv
        case '*'
            echo "Selección inválida; no se inició Claude Code." >&2
            return 2
    end
end
