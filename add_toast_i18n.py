import re

def update_dict(file_path, key, value):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    if f'"{key}":' not in content:
        insert_str = f',\n  "{key}": "{value}"\n}};'
        content = content.replace('\n};', insert_str)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)

update_dict("apps/web/lib/i18n/en.ts", "Değişiklikler kaydedildi", "Changes saved")
update_dict("apps/web/lib/i18n/es.ts", "Değişiklikler kaydedildi", "Cambios guardados")
print("Toast i18n added")
