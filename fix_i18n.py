import re

files = [
    "apps/web/app/page.tsx",
    "apps/web/app/dashboard/page.tsx",
    "apps/web/app/login/page.tsx",
]

replacements = {
    # page.tsx
    r'>_ içinde yayına alın\.': r'>_ ${t("içinde yayına alın.")}',
    r'>_ \$\{t\("içinde yayına alın\."\)\}': r'>_ ${t("içinde yayına alın.")}', # prevent double replace
    r'Modern geliştiriciler için otonom sunucu yönetimi, tam entegre veritabanı ve sıfır gecikmeli global dağıtım ağı\.': r'{t("Modern geliştiriciler için otonom sunucu yönetimi, tam entegre veritabanı ve sıfır gecikmeli global dağıtım ağı.")}',
    r'Hemen Başlayın': r'{t("Hemen Başlayın")}',
    r'Otonom Veritabanı Sistemi': r'{t("Otonom Veritabanı Sistemi")}',
    r"Clous veritabanı cluster'ınızı saniyeler içinde oluşturur, yapılandırır ve projenize bağlar\.": r'{t("Clous veritabanı cluster\'ınızı saniyeler içinde oluşturur, yapılandırır ve projenize bağlar.")}',
    r'Sıfır Güvenlik Açığı': r'{t("Sıfır Güvenlik Açığı")}',
    r'Gelişmiş WAF ve otomatik SSL yapılandırması ile sisteminiz anında enterprise seviyesinde koruma altına alınır\.': r'{t("Gelişmiş WAF ve otomatik SSL yapılandırması ile sisteminiz anında enterprise seviyesinde koruma altına alınır.")}',
    r'Tam Uyumlu Terminal': r'{t("Tam Uyumlu Terminal")}',
    r'Clous CLI ile tüm yönetim süreçlerini yerel terminalinizden saniyeler içinde halledin\.': r'{t("Clous CLI ile tüm yönetim süreçlerini yerel terminalinizden saniyeler içinde halledin.")}',
    r'Yeni Nesil Otonom Dağıtım': r'{t("Yeni Nesil Otonom Dağıtım")}',
    r'Kodunuzu pushlayın, gerisini Clous halletsin\.': r'{t("Kodunuzu pushlayın, gerisini Clous halletsin.")}',
    r'>GitHub Entegrasyonu<': r'>{t("GitHub Entegrasyonu")}<',
    r"Main branch'e pushladığınız an otomatik build ve deploy süreçleri tetiklenir\.": r'{t("Main branch\'e pushladığınız an otomatik build ve deploy süreçleri tetiklenir.")}',
    r'>Anında dağıtım<': r'>{t("Anında dağıtım")}<',
    r'>Sıfır Gecikme<': r'>{t("Sıfır Gecikme")}<',
    r'>Gelişmiş Analitik<': r'>{t("Gelişmiş Analitik")}<',
    r'>Gerçek zamanlı trafik<': r'>{t("Gerçek zamanlı trafik")}<',
    r'>Gizlilik Politikası<': r'>{t("Gizlilik Politikası")}<',
    r'>Kullanım Şartları<': r'>{t("Kullanım Şartları")}<',
    r'>Sistem Durumu<': r'>{t("Sistem Durumu")}<',
    r'Altyapı Döngüsü': r'{t("Altyapı Döngüsü")}',
    r'Altyapı Katmanları': r'{t("Altyapı Katmanları")}',
    r'>Terminal Bağlantısı<': r'>{t("Terminal Bağlantısı")}<',
    r'>Otonom Veritabanı<': r'>{t("Otonom Veritabanı")}<',
    r'>İzolasyon ve Güvenlik<': r'>{t("İzolasyon ve Güvenlik")}<',
    r'Limitsiz Organizasyon': r'{t("Limitsiz Organizasyon")}',
    r'Projelerinizi özgürce oluşturun\. Tüm altyapıyı panonuzda limitsiz organize edin\.': r'{t("Projelerinizi özgürce oluşturun. Tüm altyapıyı panonuzda limitsiz organize edin.")}',
    
    # login/page.tsx
    r"Clous'a Giriş Yap": r'{t("Clous\'a Giriş Yap")}',
    r'>Hesap Oluştur<': r'>{t("Hesap Oluştur")}<',
    r'Hoş Geldiniz': r'{t("Hoş Geldiniz")}',
    r'Sistem durumu harika\. Saniyeler içinde giriş yaparak otonom sunucularınızın kontrolünü elinize alın\.': r'{t("Sistem durumu harika. Saniyeler içinde giriş yaparak otonom sunucularınızın kontrolünü elinize alın.")}',
    r'Clous ile projenizi saniyeler içinde yayına alın ve tüm dünyaya açılın\. Sadece birkaç tıklamayla her şey hazır\.': r'{t("Clous ile projenizi saniyeler içinde yayına alın ve tüm dünyaya açılın. Sadece birkaç tıklamayla her şey hazır.")}',
    r'Google ile devam et': r'{t("Google ile devam et")}',
    r'GitHub ile devam et': r'{t("GitHub ile devam et")}',
    r'Henüz hesabınız yok mu\?': r'{t("Henüz hesabınız yok mu?")}',
    r'Zaten hesabınız var mı\?': r'{t("Zaten hesabınız var mı?")}',
    r'>Kayıt Olun<': r'>{t("Kayıt Olun")}<',
    r'>Giriş Yapın<': r'>{t("Giriş Yapın")}<',
    r'Giriş yapılıyor\.\.\.': r'{t("Giriş yapılıyor...")}',
    r'Google ile giriş başarısız oldu\.': r'{t("Google ile giriş başarısız oldu.")}',
    r'Hesabınıza giriş yapılıyor\.\.\.': r'{t("Hesabınıza giriş yapılıyor...")}',
    r'Hesabınız başarıyla oluşturuldu\.\.\.': r'{t("Hesabınız başarıyla oluşturuldu...")}',
    r'Beklenmeyen bir hata oluştu\.': r'{t("Beklenmeyen bir hata oluştu.")}',

    # dashboard/page.tsx
    r'>Yeni Proje Oluştur<': r'>{t("Yeni Proje Oluştur")}<',
    r'>Projelerim<': r'>{t("Projelerim")}<',
    r'>Faturalandırma<': r'>{t("Faturalandırma")}<',
    r'>Ayarlar<': r'>{t("Ayarlar")}<',
    r'>Çıkış Yap<': r'>{t("Çıkış Yap")}<',
    r'>Proje Adı<': r'>{t("Proje Adı")}<',
    r'Projenize kısa ve anlaşılır bir isim verin\.': r'{t("Projenize kısa ve anlaşılır bir isim verin.")}',
    r'Örn: clous-landing-page': r'{t("Örn: clous-landing-page")}',
    r'>Plan Seçimi<': r'>{t("Plan Seçimi")}<',
    r'>Bedava<': r'>{t("Bedava")}<',
    r'>Aylık 10\$<': r'>{t("Aylık 10$")}<',
    r'>Aylık 30\$<': r'>{t("Aylık 30$")}<',
    r'>CLI Entegrasyonu<': r'>{t("CLI Entegrasyonu")}<',
    r'Projenizi yerel ortamınızda bağlamak için sisteminizde Clous CLI.ın kurulu olduğundan emin olun\.': r'{t("Projenizi yerel ortamınızda bağlamak için sisteminizde Clous CLI\'ın kurulu olduğundan emin olun.")}',
    r'Kurulum tamamlandıktan sonra terminalinize <code className="text-zinc-300 bg-zinc-800 px-1 py-0\.5 rounded">clous login<\/code> yazarak hesabınızı entegre edebilirsiniz\. Herhangi bir ekstra token kopyalamanıza gerek yoktur\.': r'{t("Kurulum tamamlandıktan sonra terminalinize")} <code className="text-zinc-300 bg-zinc-800 px-1 py-0.5 rounded">clous login</code> {t("yazarak hesabınızı entegre edebilirsiniz. Herhangi bir ekstra token kopyalamanıza gerek yoktur.")}',
    r'>Projeyi Oluştur<': r'>{t("Projeyi Oluştur")}<',
    r'>Kapat<': r'>{t("Kapat")}<',
    r'>Genel Bakış<': r'>{t("Genel Bakış")}<',
    r'placeholder="Proje veya kaynak ara\.\.\."': r'placeholder={t("Proje veya kaynak ara...")}',
}

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # We'll do exact/regex replace but carefully
    for pattern, replacement in replacements.items():
        # Only replace if not already wrapped in {t("...")} or t("...")
        # Since our replacement has {t( or t(, we can just replace and then clean up double wrapping.
        content = re.sub(pattern, replacement, content)
        
    # Clean up double wraps like {t("{t("...
    content = content.replace('{t("{t(', '{t(').replace('}")}")}', '}")}')
    content = content.replace('{t(`{t(', '{t(').replace(')}`)}', ')})')
    content = content.replace('>{t("{t(', '>{t(')
    content = content.replace('{t(">{t(', '>{t(')
    content = content.replace('{t(">{t("', '>{t("')
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print("Done replacing.")
