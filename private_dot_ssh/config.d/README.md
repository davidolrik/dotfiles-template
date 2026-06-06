# SSH Config rules

The main `~/.ssh/config` includes every `*.config` file in this directory in
alphabetical order — use numeric prefixes to control ordering:

- `00-*` global settings that hosts may override
- `10-*` … `89-*` host definitions, one file per customer/project/context
- `99-*` catch-all defaults applied last (first match wins in ssh, so
  defaults must come after specific hosts)

## Machine-specific files

Embed the machine name in the filename and add a matching conditional to
`.chezmoiignore`, then the file is only deployed on that machine:

- `10-work-laptop-customer.config` + an ignore rule for
  `.ssh/config.d/*-work-laptop-*.config` on machines not named `work-laptop`
