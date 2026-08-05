# Crush Advisor

Advisor skill for the Crush coding agent inspired by Claude's advisor tool, designed to improve the outputs of smaller/cheaper models.

## Features

- Models can call an advisor before doing complex work to get advice, allowing you to use a cheap executor model with plans and advice from stronger models, saving against using a more expensive model for everything.
- Set your own model to use for the advisor in the configuration file.
- Install script to install the skill, the hook, and the `CRUSH.md` instructions. Supports both `crush.json` and the new `crushrc`.

## Installation

1. Clone the repository
2. Run the install script. Choose if you use the `crush.json` format or the new `crushrc` format, and if you use a custom configuration directory. The configuration directory defaults to `~/.config/crush`, and the skills directory uses `.agents/skills/`, as that is where crush picks up global skills.
**Usage:** `install.sh [--json|--crushrc] [--config=DIR]`

## How it works

- A skill and instructions in CRUSH.md tell the agent when and how to use the skill.
- A hook runs when the agent calls the skill. The agent runs a bash `echo advisor` -> the hook intercepts and runs the scripts -> injects advice from the advisor into the session context.
- `ask-advisor.sh` is the hook script; it checks for `echo advisor` on every bash run, pulls the chosen model from `crush-config/config.txt`, runs `session-dump.sh`, does a `crush run` with the advisor prompt and session context, then formats the output as context for crush. It uses `crush-config/` as the working directory for the advisor with the `CRUSH.md` adding custom instructions to the advisor model.
- `session-dump.sh` pulls the session from the crush database based on the session ID and working directory inserted by the hook. 
- `crush-config/config.txt` allows setting the model to use as the advisor
- `crush-config/CRUSH.md` - 
- `install.sh` as described above.

## Planned Features

- [ ] Create an MCP server as an alternative or replacement to the skill. 
  - Currently, every time the agent uses the bash skill, the hook fires and outputs to the TUI, adding some unnecessary clutter. I would swap the hook from firing on the bash tool to the `advisor` MCP tool, alleviating this issue. The agent would also call the native tool instead of calling the bash tool with `echo advisor` making it more native.
