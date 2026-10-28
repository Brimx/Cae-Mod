local vars = require("variables")

hl.config({
    input = {
        kb_layout          = "us, latam",
        numlock_by_default = false,
        repeat_delay       = 250,
        repeat_rate        = 35,
        focus_on_close     = 1,

        touchpad           = {
            natural_scroll       = true,
            disable_while_typing = vars.touchpadDisableTyping,
            scroll_factor        = vars.touchpadScrollFactor,
            -- Taps explícitos (Nivel A libinput): 1=left, 2=right, 3=middle.
            -- Sin esto el tap 3 dedos (clic central) queda en default implícito
            -- y se siente "muy preciso" por el timeout hardcodeado de libinput.
            tap_to_click         = true,
            tap_button_map       = "lrm",
            clickfinger_behavior = false,
            middle_button_emulation = true,
        },
    },

    binds = {
        scroll_event_delay = 0,
    },

    cursor = {
        hotspot_padding = 1,
    },
})

-- Override por device: este HW expone ascp1200 touchpad + mouse;
-- sin override el tap_button_map a veces no aplica (hypr #2592).
-- NOTA: input.lua requiere restart de Hyprland, no basta reload.
hl.device({
    name                    = "ascp1200:00-093a:3016-touchpad",
    tap_button_map          = "lrm",
    tap_to_click            = true,
    middle_button_emulation = true,
})

-- Bezel crea "Bezel Virtual Trackpad" (grab exclusivo + passthrough) y
-- Hyprland recibe los taps por ahí: replicar el mapeo o se pierde el
-- clic central / tap-to-click cuando bezel.service está activo.
hl.device({
    name                    = "bezel-virtual-trackpad",
    tap_button_map          = "lrm",
    tap_to_click            = true,
    middle_button_emulation = true,
})
