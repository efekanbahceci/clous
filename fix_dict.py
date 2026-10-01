import re

en_additions = {
    "Altyapı Döngüsü": "Infrastructure Cycle",
    "Altyapı Katmanları": "Infrastructure Layers",
    "Terminal Bağlantısı": "Terminal Connection",
    "Otonom Veritabanı": "Autonomous Database",
    "İzolasyon ve Güvenlik": "Isolation & Security",
    "Limitsiz Organizasyon": "Unlimited Organization",
    "Projelerinizi özgürce oluşturun. Tüm altyapıyı panonuzda limitsiz organize edin.": "Create projects freely. Organize all infrastructure seamlessly from your dashboard.",
    "Giriş yapılıyor...": "Logging in...",
    "Google ile giriş başarısız oldu.": "Google login failed.",
    "Hesabınıza giriş yapılıyor...": "Logging into your account...",
    "Hesabınız başarıyla oluşturuldu...": "Account successfully created...",
    "Beklenmeyen bir hata oluştu.": "An unexpected error occurred.",
    "Projenize kısa ve anlaşılır bir isim verin.": "Give your project a short and clear name.",
    "Örn: clous-landing-page": "E.g.: clous-landing-page",
    "Genel Bakış": "Overview",
    "Proje veya kaynak ara...": "Search project or resource..."
}

es_additions = {
    "Altyapı Döngüsü": "Ciclo de Infraestructura",
    "Altyapı Katmanları": "Capas de Infraestructura",
    "Terminal Bağlantısı": "Conexión de Terminal",
    "Otonom Veritabanı": "Base de Datos Autónoma",
    "İzolasyon ve Güvenlik": "Aislamiento y Seguridad",
    "Limitsiz Organizasyon": "Organización Ilimitada",
    "Projelerinizi özgürce oluşturun. Tüm altyapıyı panonuzda limitsiz organize edin.": "Crea proyectos libremente. Organiza toda la infraestructura sin límites desde tu panel.",
    "Giriş yapılıyor...": "Iniciando sesión...",
    "Google ile giriş başarısız oldu.": "El inicio de sesión de Google falló.",
    "Hesabınıza giriş yapılıyor...": "Iniciando sesión en tu cuenta...",
    "Hesabınız başarıyla oluşturuldu...": "Cuenta creada con éxito...",
    "Beklenmeyen bir hata oluştu.": "Ocurrió un error inesperado.",
    "Projenize kısa ve anlaşılır bir isim verin.": "Dale a tu proyecto un nombre corto y claro.",
    "Örn: clous-landing-page": "Ej.: clous-landing-page",
    "Genel Bakış": "Visión General",
    "Proje veya kaynak ara...": "Buscar proyecto o recurso..."
}

def update_dict(file_path, additions):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Insert before the last '};'
    insert_str = ",\n" + ",\n".join(f'  "{k}": "{v}"' for k, v in additions.items()) + "\n};"
    content = content.replace('\n};', insert_str)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

update_dict("apps/web/lib/i18n/en.ts", en_additions)
update_dict("apps/web/lib/i18n/es.ts", es_additions)

print("Dictionaries updated.")
en_additions2 = {
    "Tıpkı kodunuzdaki katmanlar gibi, altyapınız da mükemmel bir mimariyle üst üste inşa edilir. Terminal komutlarıyla başlayın, gerisini yığının": "Just like layers in your code, your infrastructure is built upon a perfect architecture. Start with terminal commands, and leave the rest to the power of the stack",
    "gücüne bırakın.": "."
}
es_additions2 = {
    "Tıpkı kodunuzdaki katmanlar gibi, altyapınız da mükemmel bir mimariyle üst üste inşa edilir. Terminal komutlarıyla başlayın, gerisini yığının": "Al igual que las capas en su código, su infraestructura se basa en una arquitectura perfecta. Comience con comandos de terminal y deje el resto al poder de la pila",
    "gücüne bırakın.": "."
}
update_dict("apps/web/lib/i18n/en.ts", en_additions2)
update_dict("apps/web/lib/i18n/es.ts", es_additions2)
