"""Build a self-contained Luau LocalScript without network imports."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
MODULES = {'Config': 'core/Config', 'Registry': 'core/Registry', 'Movement': 'utils/Movement', 'Interaction': 'utils/Interaction', 'Evade': 'features/Evade', 'Interface': 'ui/Interface', 'Tracker': 'features/Tracker', 'Automation': 'features/Automation', 'Monitor': 'features/Monitor'}
entry = (SRC / "Hub.client.lua").read_text(encoding="utf-8")
start = entry.index("-- BEGIN IMPORTS")
end = entry.index("-- END IMPORTS") + len("-- END IMPORTS")
parts = []
for name, relative in MODULES.items():
    source = (SRC / (relative + ".lua")).read_text(encoding="utf-8").rstrip()
    parts.append("-- Module: " + relative + "\nlocal " + name + " = (function()\n" + source + "\nend)()")
output = entry[:start] + "\n\n".join(parts) + entry[end:]
path = ROOT / "dist" / "dandys_world_modular.lua"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(output, encoding="utf-8")
print(path)
