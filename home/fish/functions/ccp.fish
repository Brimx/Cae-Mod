function ccp --description "Proveedor activo de Claude Code (or | th | auto)"
    set -l prov $argv[1]
    switch $prov
        case or openrouter
            set -U CC_PROVIDER openrouter
        case th tokenharbor
            set -U CC_PROVIDER tokenharbor
        case auto
            set -U CC_PROVIDER auto
        case ''
            set -q CC_PROVIDER; or set -U CC_PROVIDER openrouter
            echo "Proveedor activo: $CC_PROVIDER"
            echo "Usa: ccp or | ccp th | ccp auto"
            return 0
        case '*'
            echo "Proveedor no válido: $prov"
            echo "Usa: ccp or | ccp th | ccp auto"
            return 1
    end
    echo "Proveedor -> $CC_PROVIDER"
end
