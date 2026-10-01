import json

def dedup_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Simple extraction of the dictionary block
    start_idx = content.find('{')
    end_idx = content.rfind('}')
    
    dict_content = content[start_idx:end_idx+1]
    
    # We can parse it by replacing some syntax to make it valid JSON, 
    # but it's simpler to just rebuild the TS object by parsing lines.
    
    lines = content.split('\n')
    seen_keys = set()
    new_lines = []
    
    for line in lines:
        if ':' in line and '"' in line:
            key_match = line.strip().split(':')[0].strip('"')
            if key_match in seen_keys:
                continue
            seen_keys.add(key_match)
        new_lines.append(line)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))

dedup_file("apps/web/lib/i18n/en.ts")
dedup_file("apps/web/lib/i18n/es.ts")
print("Dedup done.")
