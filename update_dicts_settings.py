import re

en_additions = {
    "Profil": "Profile",
    "Güvenlik": "Security",
    "Genel": "General",
    "Profil Fotoğrafı Seç": "Choose Profile Picture",
    "Değişiklikleri Kaydet": "Save Changes",
    "Eski Şifre": "Current Password",
    "Yeni Şifre": "New Password",
    "Şifreyi Güncelle": "Update Password",
    "Proje Ayarları": "Project Settings",
    "Otomatik Dağıtım": "Auto Deployment",
    "Projeleriniz için otomatik build süreçlerini aktifleştirin.": "Enable automatic build processes for your projects.",
    "Gelişmiş Analitik": "Advanced Analytics",
    "Proje trafik verilerini detaylı analiz edin.": "Analyze project traffic data in detail."
}

es_additions = {
    "Profil": "Perfil",
    "Güvenlik": "Seguridad",
    "Genel": "General",
    "Profil Fotoğrafı Seç": "Elegir Foto de Perfil",
    "Değişiklikleri Kaydet": "Guardar Cambios",
    "Eski Şifre": "Contraseña Actual",
    "Yeni Şifre": "Nueva Contraseña",
    "Şifreyi Güncelle": "Actualizar Contraseña",
    "Proje Ayarları": "Configuración del Proyecto",
    "Otomatik Dağıtım": "Despliegue Automático",
    "Projeleriniz için otomatik build süreçlerini aktifleştirin.": "Habilite procesos de compilación automáticos para sus proyectos.",
    "Gelişmiş Analitik": "Análisis Avanzado",
    "Proje trafik verilerini detaylı analiz edin.": "Analice los datos de tráfico del proyecto en detalle."
}

def update_dict(file_path, additions):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # We will inject the new keys before the last '};'
    insert_str = ",\n" + ",\n".join(f'  "{k}": "{v}"' for k, v in additions.items()) + "\n};"
    content = content.replace('\n};', insert_str)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

update_dict("apps/web/lib/i18n/en.ts", en_additions)
update_dict("apps/web/lib/i18n/es.ts", es_additions)
print("Updated dictionaries")
