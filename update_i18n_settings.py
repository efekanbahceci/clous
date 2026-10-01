import re

en_additions = {
    "İsim": "Name",
    "E-posta": "Email",
    "Bağlı Platformlar": "Connected Platforms",
    "E-postalar & Auth": "Emails & Auth",
    "İki Aşamalı Doğrulama (2FA)": "Two-Factor Authentication (2FA)",
    "E-posta Değiştir": "Change Email",
    "Bağlı Değil": "Not Connected",
    "E-postayı Güncelle": "Update Email",
    "Kişisel Bilgiler": "Personal Information",
    "Hesabınızı ekstra güvenlik katmanıyla koruyun.": "Protect your account with an extra layer of security.",
    "Aktifleştir": "Enable",
    "Pasif": "Disabled",
    "Aktif": "Active",
    "Github Hesabı": "Github Account",
    "Google Hesabı": "Google Account"
}

es_additions = {
    "İsim": "Nombre",
    "E-posta": "Correo Electrónico",
    "Bağlı Platformlar": "Plataformas Conectadas",
    "E-postalar & Auth": "Correos y Auth",
    "İki Aşamalı Doğrulama (2FA)": "Autenticación de dos factores (2FA)",
    "E-posta Değiştir": "Cambiar Correo",
    "Bağlı Değil": "No Conectado",
    "E-postayı Güncelle": "Actualizar Correo",
    "Kişisel Bilgiler": "Información Personal",
    "Hesabınızı ekstra güvenlik katmanıyla koruyun.": "Proteja su cuenta con una capa de seguridad adicional.",
    "Aktifleştir": "Habilitar",
    "Pasif": "Desactivado",
    "Aktif": "Activo",
    "Github Hesabı": "Cuenta de Github",
    "Google Hesabı": "Cuenta de Google"
}

def update_dict(file_path, additions):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    insert_str = ",\n" + ",\n".join(f'  "{k}": "{v}"' for k, v in additions.items()) + "\n};"
    content = content.replace('\n};', insert_str)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

update_dict("apps/web/lib/i18n/en.ts", en_additions)
update_dict("apps/web/lib/i18n/es.ts", es_additions)
print("Updated i18n dictionaries")
