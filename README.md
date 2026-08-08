# Crush Advisor

Advisor skill for the Crush coding agent inspired by Claude's advisor tool, designed to improve the outputs of smaller/cheaper models.

## Features

- Models can call an advisor before doing complex work to get advice, allowing you to use a cheap executor model with plans and advice from stronger models, saving against using a more expensive model for everything.
- Set your own model to use for the advisor in the configuration file.
- Install script to install the skill, the hook, and the `CRUSH.md` instructions. Supports both `crush.json` and the new `crushrc`.

## Installation and Configuration

1. Clone the repository.
2. Run the install script. Choose if you use the `crush.json` format or the new `crushrc` format, and if you use custom directories. The configuration directory defaults to `~/.config/crush` (override with `--config-dir`), and the skills directory defaults to `~/.agents/skills`, where crush picks up global skills (override with `--skill-dir`; the hook is wired to the chosen directory).

**Usage:** 
```
install.sh [--json|--crushrc] [--config-dir=DIR] [--skill-dir=DIR]
```

3. Add your preferred model to `crush-config/config.txt`. For example, `model=hyper/qwen3.8-max`

## How it works

- A skill and instructions in CRUSH.md tell the agent when and how to use the skill.
- A hook runs when the agent calls the skill. The agent runs a bash `echo advisor` -> the hook intercepts and runs the scripts -> injects advice from the advisor into the session context.
- `ask-advisor.sh` is the hook script; it checks for `echo advisor` on every bash run, pulls the chosen model from `crush-config/config.txt`, runs `session-dump.sh`, does a `crush run` with the advisor prompt and session context, then formats the output as context for crush. It uses `crush-config/` as the working directory for the advisor with the `CRUSH.md` adding custom instructions to the advisor model.
- `session-dump.sh` pulls the session from the crush database based on the session ID and working directory inserted by the hook. 
- `crush-config/config.txt` allows setting the model to use as the advisor.
- `install.sh` as described above.

## Planned Features

- [ ] Create an MCP server as an alternative or replacement to the skill. 
  - Currently, every time the agent uses the bash skill, the hook fires and outputs to the TUI, adding some unnecessary clutter. I would swap the hook from firing on the bash tool to the `advisor` MCP tool, alleviating this issue. The agent would also call the native tool instead of calling the bash tool with `echo advisor` making it more native.

  ## Known Limitations

 Because crush lacks a dedicated plugins or extensions system, this project is quite "hacky," but it does work well. However, here are some things that I don't like that I could not find a way to work around with the limitations of Crush:

- No way to disable the skill on the fly or depending on the model. If Crush passed the current model name into crushrc as an environmental variable that was updated on model change you could disable it depending on the model with bash, or Crush could simply have a slash command to disable a skill like oh-my-pi has.
- The script to pull the session transcript from the database could be avoided entirely with a new hook environmental variable that offers the entire session context.
- A way to disable or customize the verbosity of the hook statements would be nice, although it doesn't affect how well it works.
