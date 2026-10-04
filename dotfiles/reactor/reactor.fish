# ☢ REACTOR — fish integration (v3)
# Installed to ~/.config/reactor/reactor.fish and sourced at the END of
# config.fish, so it wins over any older prompt/greeting defined there.

function fish_greeting
    if status is-interactive; and not set -q REACTOR_GREETED
        set -gx REACTOR_GREETED 1
        ~/.config/reactor/reactor-gauges.sh $FISH_VERSION
    end
end

# ☢ REACTOR [ONLINE] ~ ›        (turns red with [FAULT n] after a failed command)
function fish_prompt
    set -l last $status
    set -l b (set_color --bold 39ff14)
    set -l d (set_color 1f8f0b)
    set -l x (set_color --bold ff2a2a)
    set -l n (set_color normal)
    if test $last -eq 0
        echo -n $b'☢ REACTOR [ONLINE] '$d(prompt_pwd)' '$b'› '$n
    else
        echo -n $x'☢ REACTOR [FAULT '$last'] '$d(prompt_pwd)' '$x'› '$n
    end
end

function fish_right_prompt
    echo -n (set_color 1f8f0b)(date +%H:%M:%S)(set_color normal)
end

alias reactor '~/.config/waybar/scripts/reactor-monitor.sh'
alias core    '~/.config/reactor/reactor-gauges.sh $FISH_VERSION'
