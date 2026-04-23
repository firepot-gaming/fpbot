#!/usr/bin/env bash
# =============================================================================
# agent-monitor.sh — Terminal-based agent monitoring dashboard
# =============================================================================
# Renders a real-time terminal dashboard showing agent activity by tailing
# logs/agent-events.jsonl. Pure bash + standard tools (awk, sed, tail, tput).
#
# Usage:
#   ./scripts/agent-monitor.sh              # Live monitoring (default)
#   ./scripts/agent-monitor.sh --once       # One-shot display
#   ./scripts/agent-monitor.sh --session ID # Watch specific session
#   ./scripts/agent-monitor.sh --clear      # Clear events and start fresh
#
# JSONL event format expected:
#   {"ts":"2026-04-01T14:30:01Z","event":"agent:start","agent":"security-auditor","session":"s_abc123"}
#   {"ts":"2026-04-01T14:30:15Z","event":"agent:complete","agent":"security-auditor","status":"ok","findings":2,"session":"s_abc123"}
#   {"ts":"2026-04-01T14:30:16Z","event":"agent:finding","agent":"security-auditor","severity":"warning","message":"...","session":"s_abc123"}
#   {"ts":"2026-04-01T14:30:17Z","event":"flow","from":"security-auditor","to":"lead","type":"audit","session":"s_abc123"}
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$PROJECT_DIR/logs/agent-events.jsonl"
REFRESH_INTERVAL=1
MAX_TIMELINE_ENTRIES=10

# ---------------------------------------------------------------------------
# ANSI color codes
# ---------------------------------------------------------------------------
RST="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BG_BLUE="\033[44m"

# Unicode box-drawing characters
H_LINE="═"
V_LINE="║"
TL_CORNER="╔"
TR_CORNER="╗"
BL_CORNER="╚"
BR_CORNER="╝"
T_LEFT="╠"
T_RIGHT="╣"

# Status icons
ICON_DONE="OK"
ICON_RUNNING="~~"
ICON_QUEUED=".."
ICON_ERROR="!!"
ICON_BULLET_ACTIVE="*"
ICON_BULLET_INACTIVE="o"
ICON_ARROW="-->"
ICON_EVENT=">"
ICON_TELESCOPE="[#]"

# ---------------------------------------------------------------------------
# CLI argument parsing
# ---------------------------------------------------------------------------
MODE="watch"        # watch | once
SESSION_FILTER=""   # empty = all sessions

while [[ $# -gt 0 ]]; do
    case "$1" in
        --once)
            MODE="once"
            shift
            ;;
        --session)
            SESSION_FILTER="$2"
            shift 2
            ;;
        --clear)
            if [[ -f "$LOG_FILE" ]]; then
                > "$LOG_FILE"
                echo "Cleared $LOG_FILE"
            else
                echo "No log file to clear."
            fi
            exit 0
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--once] [--session ID] [--clear] [--help]"
            echo ""
            echo "  --once        One-shot display (no refresh)"
            echo "  --session ID  Filter events by session ID"
            echo "  --clear       Clear the event log and exit"
            echo "  --help        Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Utility: extract a JSON string value by key (lightweight, no jq needed)
# Handles: "key":"value" and "key": "value"
# Does NOT handle nested objects as values — sufficient for flat JSONL events.
# ---------------------------------------------------------------------------
json_get() {
    local line="$1"
    local key="$2"
    # Try to extract string value first
    local val
    val=$(echo "$line" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if [[ -n "$val" ]]; then
        echo "$val"
        return
    fi
    # Try numeric value
    val=$(echo "$line" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    echo "$val"
}

# ---------------------------------------------------------------------------
# Auto-detect project name from CLAUDE.md or directory name
# ---------------------------------------------------------------------------
detect_project_name() {
    local claude_md="$PROJECT_DIR/CLAUDE.md"
    if [[ -f "$claude_md" ]]; then
        # Look for "# [SPEC] Project Name" or "# Something"
        local name
        name=$(head -5 "$claude_md" | sed -n 's/^# *\(.*\)/\1/p' | head -1)
        if [[ -n "$name" ]]; then
            echo "$name"
            return
        fi
    fi
    basename "$PROJECT_DIR"
}

PROJECT_NAME="$(detect_project_name)"

# ---------------------------------------------------------------------------
# Draw a horizontal line of given width with optional left/right corners
# ---------------------------------------------------------------------------
draw_hline() {
    local width="$1"
    local left="${2:-$H_LINE}"
    local right="${3:-$H_LINE}"
    local inner=$((width - 2))
    printf "%s" "$left"
    for ((i = 0; i < inner; i++)); do
        printf "%s" "$H_LINE"
    done
    printf "%s" "$right"
}

# ---------------------------------------------------------------------------
# Print a padded line within the box (left-aligned text, padded to width)
# ---------------------------------------------------------------------------
box_line() {
    local width="$1"
    local content="$2"
    local inner=$((width - 4))  # 2 for borders, 2 for padding spaces
    # Strip ANSI codes to calculate visible length
    local visible
    visible=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local vis_len=${#visible}
    local pad=$((inner - vis_len))
    if [[ $pad -lt 0 ]]; then
        # Content exceeds box width — truncate the visible text.
        # We allow a small overflow rather than complex ANSI-aware truncation,
        # but reset formatting and close the border.
        printf "%s " "$V_LINE"
        printf "%b" "$content"
        printf "${RST} %s\n" "$V_LINE"
        return
    fi
    printf "%s " "$V_LINE"
    printf "%b" "$content"
    printf "%*s" "$pad" ""
    printf " %s\n" "$V_LINE"
}

# ---------------------------------------------------------------------------
# Parse all events from JSONL, build state arrays
# Uses temp files to avoid subshell variable scoping issues.
# ---------------------------------------------------------------------------
parse_events() {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Initialize output files
    : > "$tmpdir/agents"         # order|agent_name|status|findings_count
    : > "$tmpdir/flows"          # from|to|type
    : > "$tmpdir/timeline"       # timestamp|icon|message
    echo "0" > "$tmpdir/start_epoch"

    if [[ ! -f "$LOG_FILE" ]] || [[ ! -s "$LOG_FILE" ]]; then
        echo "$tmpdir"
        return
    fi

    # Use awk to parse all events in a single pass — avoids bash associative
    # arrays (which require bash 4+ and macOS ships with bash 3).
    awk -v session_filter="$SESSION_FILTER" \
        -v agents_file="$tmpdir/agents" \
        -v flows_file="$tmpdir/flows" \
        -v timeline_file="$tmpdir/timeline" \
        -v epoch_file="$tmpdir/start_epoch" \
    '
    # Extract a JSON string value by key.
    # Compatible with BSD awk (macOS) — no gawk-specific features.
    function jget(line, key,    pat, val, start, rest) {
        # Try string value: "key":"value" or "key" : "value"
        pat = "\"" key "\"[ ]*:[ ]*\""
        if (match(line, pat)) {
            start = RSTART + RLENGTH
            rest = substr(line, start)
            if (match(rest, /^[^"]*/)) {
                val = substr(rest, 1, RLENGTH)
                return val
            }
        }
        # Try numeric value: "key":123 or "key": 123
        pat = "\"" key "\"[ ]*:[ ]*[0-9]+"
        if (match(line, pat)) {
            val = substr(line, RSTART, RLENGTH)
            sub(/^"[^"]*"[ ]*:[ ]*/, "", val)
            return val
        }
        return ""
    }

    # Extract time portion from ISO timestamp (e.g. 2026-04-01T14:30:01Z -> 14:30:01)
    function time_part(ts,    idx, rest) {
        idx = index(ts, "T")
        if (idx > 0) {
            rest = substr(ts, idx + 1)
            sub(/[^0-9:].*/, "", rest)
            return rest
        }
        return ts
    }

    BEGIN {
        order_counter = 0
        first_ts = ""
    }

    {
        line = $0
        if (line !~ /\{/) next

        # Session filter
        if (session_filter != "") {
            sess = jget(line, "session")
            if (sess != session_filter) next
        }

        event = jget(line, "event")
        ts = jget(line, "ts")
        agent = jget(line, "agent")

        if (first_ts == "" && ts != "") first_ts = ts
        tp = time_part(ts)

        if (event == "agent:start") {
            if (!(agent in agent_status)) {
                agent_order[agent] = order_counter++
                agent_findings[agent] = 0
            }
            agent_status[agent] = "RUNNING"
            print tp "|>|" agent " started" >> timeline_file
        }
        else if (event == "agent:complete") {
            st = jget(line, "status")
            fc = jget(line, "findings")
            if (st == "error") {
                agent_status[agent] = "ERROR"
            } else {
                agent_status[agent] = "DONE"
            }
            if (fc != "") agent_findings[agent] = fc + 0
            if (!(agent in agent_order)) {
                agent_order[agent] = order_counter++
            }
            ft = ""
            if (fc + 0 > 0) ft = " (" fc " findings)"
            icon = (st == "error") ? "!!" : "OK"
            print tp "|" icon "|" agent " done" ft >> timeline_file
        }
        else if (event == "agent:finding") {
            if (!(agent in agent_findings)) agent_findings[agent] = 0
            agent_findings[agent]++
            sev = jget(line, "severity")
            msg = jget(line, "message")
            short = substr(msg, 1, 30)
            print tp "|!|" agent ": [" sev "] " short >> timeline_file
        }
        else if (event == "agent:queue" || event == "agent:queued") {
            if (!(agent in agent_order)) {
                agent_order[agent] = order_counter++
                agent_findings[agent] = 0
            }
            agent_status[agent] = "QUEUED"
            print tp "|..|" agent " queued" >> timeline_file
        }
        else if (event == "flow" || index(event, "flow:") == 1) {
            fr = jget(line, "agent")
            if (fr == "" || fr == "_orchestrator") fr = jget(line, "from")
            to = jget(line, "to")
            # flow type from "flow:audit" format or "type" field
            if (index(event, "flow:") == 1) {
                ft = substr(event, 6)
            } else {
                ft = jget(line, "type")
            }
            if (fr != "" && to != "" && ft != "") {
                print fr "|" to "|" ft >> flows_file
            }
        }
    }

    END {
        # Write agents sorted by order
        for (a in agent_status) {
            ord = (a in agent_order) ? agent_order[a] : 999
            fc = (a in agent_findings) ? agent_findings[a] : 0
            print ord "|" a "|" agent_status[a] "|" fc >> agents_file
        }

        # Write first timestamp for epoch calculation
        if (first_ts != "") print first_ts > epoch_file
    }
    ' "$LOG_FILE"

    # Sort agents by order
    if [[ -s "$tmpdir/agents" ]]; then
        sort -t'|' -k1 -n "$tmpdir/agents" > "$tmpdir/agents_sorted"
        mv "$tmpdir/agents_sorted" "$tmpdir/agents"
    fi

    # Convert first timestamp to epoch for elapsed time calculation
    local first_ts_val
    first_ts_val=$(cat "$tmpdir/start_epoch" 2>/dev/null || echo "0")
    if [[ "$first_ts_val" != "0" && "$first_ts_val" == *"T"* ]]; then
        local epoch=0
        # macOS date
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$first_ts_val" "+%s" 2>/dev/null || true)
        # GNU date fallback
        if [[ -z "$epoch" || "$epoch" == "0" ]]; then
            epoch=$(date -d "$first_ts_val" "+%s" 2>/dev/null || echo 0)
        fi
        echo "${epoch:-0}" > "$tmpdir/start_epoch"
    fi

    echo "$tmpdir"
}

# ---------------------------------------------------------------------------
# Render the dashboard
# ---------------------------------------------------------------------------
render_dashboard() {
    local tmpdir="$1"
    local width
    width=$(tput cols 2>/dev/null || echo 70)
    # Cap width for readability, minimum 60
    [[ $width -lt 60 ]] && width=60
    [[ $width -gt 100 ]] && width=100

    local inner=$((width - 4))

    # Clear screen and move cursor to top
    printf "\033[2J\033[H"

    # ---- Header ----
    draw_hline "$width" "$TL_CORNER" "$TR_CORNER"
    echo ""
    box_line "$width" "${BOLD}${CYAN}  ${ICON_TELESCOPE} BLUEPRINT AGENT MONITOR${RST}${DIM}  •  ${PROJECT_NAME}  •  L4${RST}"
    draw_hline "$width" "$T_LEFT" "$T_RIGHT"
    echo ""
    box_line "$width" ""

    # ---- Agents Section ----
    local header_fmt
    header_fmt=$(printf "${BOLD}${WHITE}  %-28s %-14s %s${RST}" "AGENTS" "STATUS" "FINDINGS")
    box_line "$width" "$header_fmt"

    local agent_count=0
    local done_count=0
    local running_count=0
    local queued_count=0
    local error_count=0

    if [[ -s "$tmpdir/agents" ]]; then
        while IFS='|' read -r _ord agent_name status findings_count; do
            ((agent_count++)) || true
            local bullet icon status_color status_text findings_text

            case "$status" in
                DONE)
                    bullet="$ICON_BULLET_ACTIVE"
                    icon="$ICON_DONE"
                    status_color="$GREEN"
                    status_text="DONE"
                    ((done_count++)) || true
                    ;;
                RUNNING)
                    bullet="$ICON_BULLET_ACTIVE"
                    icon="$ICON_RUNNING"
                    status_color="$BLUE"
                    status_text="RUNNING"
                    ((running_count++)) || true
                    ;;
                QUEUED)
                    bullet="$ICON_BULLET_INACTIVE"
                    icon="$ICON_QUEUED"
                    status_color="$YELLOW"
                    status_text="QUEUED"
                    ((queued_count++)) || true
                    ;;
                ERROR)
                    bullet="$ICON_BULLET_ACTIVE"
                    icon="$ICON_ERROR"
                    status_color="$RED"
                    status_text="ERROR"
                    ((error_count++)) || true
                    ;;
                *)
                    bullet="$ICON_BULLET_INACTIVE"
                    icon="?"
                    status_color="$WHITE"
                    status_text="$status"
                    ;;
            esac

            if [[ "$findings_count" -gt 0 ]] 2>/dev/null; then
                findings_text="${findings_count} findings"
            else
                findings_text="-"
            fi

            # Format: bullet agent_name ... [icon] STATUS ... findings
            local agent_display
            agent_display=$(printf "  ${WHITE}${bullet} %-26s${RST} ${status_color}${icon} %-10s${RST} %s" \
                "$agent_name" "$status_text" "$findings_text")
            box_line "$width" "$agent_display"
        done < "$tmpdir/agents"
    else
        box_line "$width" "  ${DIM}No agent events recorded yet.${RST}"
    fi

    box_line "$width" ""

    # ---- Flow Section ----
    box_line "$width" "${BOLD}${WHITE}  FLOW${RST}"
    if [[ -s "$tmpdir/flows" ]]; then
        # Deduplicate flows
        sort -u "$tmpdir/flows" | while IFS='|' read -r from_agent to_agent flow_type; do
            local flow_line
            flow_line="  ${CYAN}${from_agent} ${ICON_ARROW}${flow_type}${ICON_ARROW} ${to_agent}${RST}"
            box_line "$width" "$flow_line"
        done
    else
        box_line "$width" "  ${DIM}No flow events yet.${RST}"
    fi

    box_line "$width" ""

    # ---- Timeline Section ----
    box_line "$width" "${BOLD}${WHITE}  TIMELINE${RST}"
    if [[ -s "$tmpdir/timeline" ]]; then
        # Show last N entries
        tail -n "$MAX_TIMELINE_ENTRIES" "$tmpdir/timeline" | while IFS='|' read -r ts_val icon_val msg_val; do
            local icon_color="$WHITE"
            case "$icon_val" in
                "$ICON_DONE"|"OK") icon_color="$GREEN" ;;
                "$ICON_ERROR"|"!!") icon_color="$RED" ;;
                "$ICON_EVENT"|">") icon_color="$BLUE" ;;
                "!") icon_color="$YELLOW" ;;
                *) icon_color="$DIM" ;;
            esac
            local timeline_entry
            timeline_entry="  ${DIM}${ts_val}${RST}  ${icon_color}${icon_val}${RST} ${msg_val}"
            box_line "$width" "$timeline_entry"
        done
    else
        box_line "$width" "  ${DIM}No events yet.${RST}"
    fi

    box_line "$width" ""

    # ---- Session Summary ----
    local now_epoch
    now_epoch=$(date "+%s" 2>/dev/null || echo 0)
    local start_epoch
    start_epoch=$(cat "$tmpdir/start_epoch" 2>/dev/null || echo 0)
    local elapsed_sec=0
    if [[ "$start_epoch" -gt 0 ]] 2>/dev/null; then
        elapsed_sec=$((now_epoch - start_epoch))
        [[ $elapsed_sec -lt 0 ]] && elapsed_sec=0
    fi

    local elapsed_text
    if [[ $elapsed_sec -ge 3600 ]]; then
        elapsed_text="$((elapsed_sec / 3600))h $((elapsed_sec % 3600 / 60))m"
    elif [[ $elapsed_sec -ge 60 ]]; then
        elapsed_text="$((elapsed_sec / 60))m $((elapsed_sec % 60))s"
    elif [[ $elapsed_sec -gt 0 ]]; then
        elapsed_text="${elapsed_sec}s"
    else
        elapsed_text="-"
    fi

    local summary_parts="${agent_count} agents"
    [[ $done_count -gt 0 ]]    && summary_parts="$summary_parts ${GREEN}${done_count} done${RST}"
    [[ $running_count -gt 0 ]] && summary_parts="$summary_parts ${BLUE}${running_count} running${RST}"
    [[ $queued_count -gt 0 ]]  && summary_parts="$summary_parts ${YELLOW}${queued_count} queued${RST}"
    [[ $error_count -gt 0 ]]   && summary_parts="$summary_parts ${RED}${error_count} error${RST}"

    draw_hline "$width" "$T_LEFT" "$T_RIGHT"
    echo ""
    box_line "$width" "  ${BOLD}SESSION:${RST} ${summary_parts}"
    box_line "$width" "  ${BOLD}TIME:${RST} ${elapsed_text} elapsed"
    if [[ -n "$SESSION_FILTER" ]]; then
        box_line "$width" "  ${BOLD}FILTER:${RST} session=${SESSION_FILTER}"
    fi

    # ---- Footer ----
    draw_hline "$width" "$BL_CORNER" "$BR_CORNER"
    echo ""

    if [[ "$MODE" == "watch" ]]; then
        printf "${DIM}  Refreshing every ${REFRESH_INTERVAL}s • Press Ctrl+C to exit${RST}\n"
    fi
}

# ---------------------------------------------------------------------------
# Final summary on exit (for watch mode)
# ---------------------------------------------------------------------------
show_final_summary() {
    echo ""
    echo -e "${BOLD}Agent Monitor stopped.${RST}"
    if [[ -f "$LOG_FILE" && -s "$LOG_FILE" ]]; then
        local total
        total=$(wc -l < "$LOG_FILE" | tr -d ' ')
        echo -e "  ${total} events in ${LOG_FILE}"
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# Trap SIGINT for graceful exit
# ---------------------------------------------------------------------------
cleanup() {
    # Restore cursor visibility
    tput cnorm 2>/dev/null || true
    show_final_summary
    exit 0
}
trap cleanup SIGINT SIGTERM

# ---------------------------------------------------------------------------
# Ensure log directory exists
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$LOG_FILE")"

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
if [[ "$MODE" == "once" ]]; then
    tmpdir=$(parse_events)
    render_dashboard "$tmpdir"
    rm -rf "$tmpdir"
else
    # Hide cursor for cleaner display
    tput civis 2>/dev/null || true

    while true; do
        tmpdir=$(parse_events)
        render_dashboard "$tmpdir"
        rm -rf "$tmpdir"
        sleep "$REFRESH_INTERVAL"
    done
fi
