"""Scanmuse App Store metadata for every localization, checked against Apple's limits.

    python3 aso/metadata.py          -> validate and print a summary table
    python3 aso/metadata.py --json   -> print the validated metadata as JSON

Strategy is taken from the Scanmuse/Scanlet ASO study (~/Desktop/New-App/docs/ASO-Metadata.md):
Apple indexes name + subtitle + keywords of every localization a storefront reads (US reads
en-US, es-MX, pt-BR, fr-FR, ru, ko, ar-SA, zh-Hans, zh-Hant, vi; GB reads en-GB; ...), so each
localization carries *different* high-value words instead of repeating the same ones.

Only claims that are true for Scanmuse are made (no translation, password lock or Face ID, no
"free" pricing words — App Review Guideline 2.3.7). Scanmuse syncs through the user's own iCloud,
so the copy never says "no cloud".

Limits: name <= 30 chars, subtitle <= 30 chars, keywords <= 100 UTF-8 bytes, promo <= 170 chars,
description <= 4000 chars.
"""
from __future__ import annotations

import json
import re
import sys

BRAND = "Scanmuse"
SUPPORT_URL = "https://akbaralikhasanov.github.io/pagewise/support.html"
PRIVACY_URL = "https://akbaralikhasanov.github.io/pagewise/privacy.html"
EULA_URL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
PRIMARY = "en-US"

EN_NAME = f"{BRAND}: PDF Scanner & OCR"

EN_PROMO = ("Scan documents to PDF in seconds, copy text with on-device OCR and sign anything. "
            "No ads, no tracking: your library syncs only through your own iCloud.")


def en_desc(spell_recognise: bool = False) -> str:
    rec = "recognise" if spell_recognise else "recognize"
    return (
        f"{BRAND} turns your iPhone into a fast, reliable document scanner.\n\n"
        "Point your camera at any receipt, note, textbook page, ID or contract and get a clean, corrected scan "
        f"in seconds. On-device text recognition (OCR) lets you {rec}, search and copy every word, no internet "
        "connection needed, and your documents never leave your device for processing.\n\n"
        "FEATURES\n"
        "- Live document scanning with automatic edge detection\n"
        "- On-device OCR: search, copy, or have any recognized text read aloud\n"
        "- Add your handwritten signature to any page\n"
        "- Tags, favorites and search across titles and scanned text\n"
        "- Image filters: original, enhanced, grayscale, black & white\n"
        "- iCloud sync keeps your library up to date on all your devices\n"
        "- Home screen widget with your latest scans\n\n"
        "Scanning, tagging and organizing is always free. Scanmuse Pro unlocks exporting and sharing finished "
        "documents as searchable PDFs or plain text.\n\n"
        "PRIVACY\n"
        "Scanmuse runs no servers of its own. There are no ads, no analytics and no tracking."
    )


def legal(privacy_label: str = "Privacy Policy", terms_label: str = "Terms of Use (EULA)",
          header: str = "TERMS & PRIVACY") -> str:
    return f"\n\n{header}\n{terms_label}: {EULA_URL}\n{privacy_label}: {PRIVACY_URL}"


# Localized descriptions (conversion copy — Apple does not index the description).
# Feature list is intentionally identical in substance across languages.
DESC = {
    "tr": ("Scanmuse, iPhone'unuzu hızlı ve güvenilir bir belge tarayıcıya dönüştürür.\n\n"
           "Kamerayı fiş, not, kimlik veya sözleşmeye tutun; saniyeler içinde temiz bir tarama alın. Cihaz üzerinde "
           "çalışan metin tanıma (OCR) ile her kelimeyi arayın ve kopyalayın; internet gerekmez, belgeleriniz "
           "işlenmek üzere cihazdan çıkmaz.\n\n"
           "ÖZELLİKLER\n- Otomatik kenar algılamalı canlı tarama\n- Cihaz üzerinde OCR: ara, kopyala, sesli okut\n"
           "- Herhangi bir sayfaya elle imza ekleyin\n- Etiketler, favoriler ve metin içinde arama\n"
           "- Görüntü filtreleri: orijinal, geliştirilmiş, gri tonlama, siyah-beyaz\n"
           "- iCloud ile tüm cihazlarda senkronizasyon\n- Ana ekran widget'ı\n\n"
           "Tarama, etiketleme ve düzenleme her zaman ücretsizdir. Scanmuse Pro, belgeleri aranabilir PDF veya düz "
           "metin olarak dışa aktarmayı ve paylaşmayı açar.\n\nGİZLİLİK\nScanmuse kendi sunucularını çalıştırmaz. "
           "Reklam, analiz ve izleme yoktur."),
    "ru": ("Scanmuse превращает iPhone в быстрый и надёжный сканер документов.\n\n"
           "Наведите камеру на чек, заметку, паспорт или договор и за секунды получите чистый скан. Распознавание "
           "текста (OCR) работает на устройстве: ищите и копируйте любое слово без интернета, документы не покидают "
           "ваш iPhone.\n\n"
           "ВОЗМОЖНОСТИ\n- Сканирование с автоматическим определением границ\n- OCR на устройстве: поиск, копирование, "
           "озвучивание текста\n- Рукописная подпись на любой странице\n- Теги, избранное и поиск по названиям и тексту\n"
           "- Фильтры: оригинал, улучшенный, градации серого, чёрно-белый\n- Синхронизация через iCloud на всех "
           "устройствах\n- Виджет на экране «Домой»\n\n"
           "Сканирование, теги и организация всегда бесплатны. Scanmuse Pro открывает экспорт и отправку документов "
           "в виде PDF с поиском или обычного текста.\n\nКОНФИДЕНЦИАЛЬНОСТЬ\nУ Scanmuse нет собственных серверов. "
           "Нет рекламы, аналитики и слежки."),
    "uk": ("Scanmuse перетворює iPhone на швидкий і надійний сканер документів.\n\n"
           "Наведіть камеру на чек, нотатку, паспорт чи договір і за секунди отримайте чіткий скан. Розпізнавання "
           "тексту (OCR) працює на пристрої: шукайте й копіюйте будь-яке слово без інтернету, документи не "
           "залишають ваш iPhone.\n\n"
           "МОЖЛИВОСТІ\n- Сканування з автоматичним визначенням меж\n- OCR на пристрої: пошук, копіювання, озвучення\n"
           "- Рукописний підпис на будь-якій сторінці\n- Теги, обране та пошук за назвами й текстом\n"
           "- Фільтри: оригінал, покращений, відтінки сірого, чорно-білий\n- Синхронізація через iCloud на всіх "
           "пристроях\n- Віджет на екрані «Додому»\n\n"
           "Сканування, теги й організація завжди безкоштовні. Scanmuse Pro відкриває експорт і надсилання "
           "документів як PDF із пошуком або звичайного тексту.\n\nКОНФІДЕНЦІЙНІСТЬ\nУ Scanmuse немає власних "
           "серверів. Немає реклами, аналітики й стеження."),
    "pt-BR": ("O Scanmuse transforma seu iPhone em um scanner de documentos rápido e confiável.\n\n"
              "Aponte a câmera para um recibo, anotação, RG ou contrato e tenha uma digitalização limpa em segundos. "
              "O reconhecimento de texto (OCR) no aparelho permite buscar e copiar cada palavra sem internet, e seus "
              "documentos não saem do iPhone.\n\n"
              "RECURSOS\n- Digitalização ao vivo com detecção automática de bordas\n- OCR no aparelho: buscar, copiar "
              "ou ouvir o texto\n- Assinatura manuscrita em qualquer página\n- Etiquetas, favoritos e busca por títulos "
              "e texto\n- Filtros: original, realçado, tons de cinza, preto e branco\n- Sincronização via iCloud em "
              "todos os dispositivos\n- Widget na tela de início\n\n"
              "Digitalizar, etiquetar e organizar é sempre grátis. O Scanmuse Pro libera exportar e compartilhar "
              "documentos como PDF pesquisável ou texto simples.\n\nPRIVACIDADE\nO Scanmuse não usa servidores "
              "próprios. Sem anúncios, sem análises, sem rastreamento."),
    "es-MX": ("Scanmuse convierte tu iPhone en un escáner de documentos rápido y confiable.\n\n"
              "Apunta la cámara a un recibo, nota, identificación o contrato y obtén un escaneo limpio en segundos. "
              "El reconocimiento de texto (OCR) en el dispositivo te deja buscar y copiar cada palabra sin internet, y "
              "tus documentos no salen de tu iPhone.\n\n"
              "FUNCIONES\n- Escaneo en vivo con detección automática de bordes\n- OCR en el dispositivo: buscar, copiar "
              "o escuchar el texto\n- Firma manuscrita en cualquier página\n- Etiquetas, favoritos y búsqueda en "
              "títulos y texto\n- Filtros: original, mejorado, escala de grises, blanco y negro\n- Sincronización con "
              "iCloud en todos tus dispositivos\n- Widget en la pantalla de inicio\n\n"
              "Escanear, etiquetar y organizar siempre es gratis. Scanmuse Pro permite exportar y compartir documentos "
              "como PDF con búsqueda o texto sin formato.\n\nPRIVACIDAD\nScanmuse no usa servidores propios. Sin "
              "anuncios, sin analíticas y sin rastreo."),
    "es-ES": ("Scanmuse convierte tu iPhone en un escáner de documentos rápido y fiable.\n\n"
              "Apunta la cámara a un recibo, una nota, el DNI o un contrato y consigue un escaneo limpio en segundos. "
              "El reconocimiento de texto (OCR) en el dispositivo te permite buscar y copiar cada palabra sin internet, "
              "y tus documentos no salen de tu iPhone.\n\n"
              "FUNCIONES\n- Escaneo en vivo con detección automática de bordes\n- OCR en el dispositivo: buscar, copiar "
              "o escuchar el texto\n- Firma manuscrita en cualquier página\n- Etiquetas, favoritos y búsqueda en "
              "títulos y texto\n- Filtros: original, mejorado, escala de grises, blanco y negro\n- Sincronización con "
              "iCloud en todos tus dispositivos\n- Widget en la pantalla de inicio\n\n"
              "Escanear, etiquetar y organizar siempre es gratis. Scanmuse Pro permite exportar y compartir documentos "
              "como PDF con búsqueda o texto sin formato.\n\nPRIVACIDAD\nScanmuse no usa servidores propios. Sin "
              "anuncios, sin analíticas y sin rastreo."),
    "de-DE": ("Scanmuse macht dein iPhone zu einem schnellen, zuverlässigen Dokumentenscanner.\n\n"
              "Richte die Kamera auf Kassenbon, Notiz, Ausweis oder Vertrag und erhalte in Sekunden einen sauberen Scan. "
              "Die Texterkennung (OCR) läuft auf dem Gerät: Jedes Wort durchsuchen und kopieren, ohne Internet, und "
              "deine Dokumente verlassen dein iPhone nicht.\n\n"
              "FUNKTIONEN\n- Live-Scan mit automatischer Kantenerkennung\n- OCR auf dem Gerät: suchen, kopieren oder "
              "vorlesen lassen\n- Handschriftliche Unterschrift auf jeder Seite\n- Tags, Favoriten und Suche in Titeln "
              "und Text\n- Bildfilter: Original, verbessert, Graustufen, Schwarzweiß\n- iCloud-Sync auf allen Geräten\n"
              "- Widget für den Home-Bildschirm\n\n"
              "Scannen, Taggen und Ordnen ist immer kostenlos. Scanmuse Pro schaltet den Export und das Teilen als "
              "durchsuchbares PDF oder Klartext frei.\n\nDATENSCHUTZ\nScanmuse betreibt keine eigenen Server. Keine "
              "Werbung, keine Analysen, kein Tracking."),
    "fr-FR": ("Scanmuse transforme votre iPhone en scanner de documents rapide et fiable.\n\n"
              "Pointez l'appareil photo sur un reçu, une note, une pièce d'identité ou un contrat et obtenez un scan net "
              "en quelques secondes. La reconnaissance de texte (OCR) sur l'appareil permet de chercher et copier chaque "
              "mot sans internet, et vos documents ne quittent jamais votre iPhone.\n\n"
              "FONCTIONS\n- Numérisation en direct avec détection automatique des bords\n- OCR sur l'appareil : "
              "rechercher, copier ou faire lire le texte\n- Signature manuscrite sur n'importe quelle page\n- Tags, "
              "favoris et recherche dans les titres et le texte\n- Filtres : original, amélioré, niveaux de gris, noir "
              "et blanc\n- Synchronisation iCloud sur tous vos appareils\n- Widget pour l'écran d'accueil\n\n"
              "Numériser, taguer et organiser est toujours gratuit. Scanmuse Pro débloque l'export et le partage en PDF "
              "avec recherche ou en texte brut.\n\nCONFIDENTIALITÉ\nScanmuse n'utilise aucun serveur propre. Pas de "
              "publicité, pas d'analyse, pas de suivi."),
    "sv": ("Scanmuse förvandlar din iPhone till en snabb och pålitlig dokumentskanner.\n\n"
           "Rikta kameran mot ett kvitto, en anteckning, ett ID-kort eller ett avtal och få en ren skanning på några "
           "sekunder. Textigenkänning (OCR) på enheten låter dig söka och kopiera varje ord utan internet, och dina "
           "dokument lämnar aldrig din iPhone.\n\n"
           "FUNKTIONER\n- Live-skanning med automatisk kantavkänning\n- OCR på enheten: sök, kopiera eller lyssna på "
           "texten\n- Handskriven signatur på valfri sida\n- Taggar, favoriter och sökning i titlar och text\n"
           "- Bildfilter: original, förbättrad, gråskala, svartvit\n- iCloud-synk mellan alla dina enheter\n"
           "- Widget för hemskärmen\n\n"
           "Att skanna, tagga och organisera är alltid gratis. Scanmuse Pro låser upp export och delning som sökbar "
           "PDF eller ren text.\n\nINTEGRITET\nScanmuse har inga egna servrar. Inga annonser, ingen analys, ingen "
           "spårning."),
    "ca": ("Scanmuse converteix el teu iPhone en un escàner de documents ràpid i fiable.\n\n"
           "Apunta la càmera a un rebut, una nota, un DNI o un contracte i obtén un escaneig net en segons. El "
           "reconeixement de text (OCR) al dispositiu et deixa cercar i copiar cada paraula sense internet, i els teus "
           "documents no surten de l'iPhone.\n\n"
           "FUNCIONS\n- Escaneig en directe amb detecció automàtica de vores\n- OCR al dispositiu: cercar, copiar o "
           "escoltar el text\n- Signatura manuscrita a qualsevol pàgina\n- Etiquetes, preferits i cerca en títols i "
           "text\n- Filtres: original, millorat, escala de grisos, blanc i negre\n- Sincronització amb iCloud a tots "
           "els dispositius\n- Widget a la pantalla d'inici\n\n"
           "Escanejar, etiquetar i organitzar sempre és gratuït. Scanmuse Pro permet exportar i compartir documents "
           "com a PDF amb cerca o text pla.\n\nPRIVACITAT\nScanmuse no fa servir servidors propis. Sense anuncis, "
           "sense analítiques i sense seguiment."),
    "it": ("Scanmuse trasforma il tuo iPhone in uno scanner di documenti veloce e affidabile.\n\n"
           "Inquadra una ricevuta, un appunto, un documento d'identità o un contratto e ottieni una scansione pulita in "
           "pochi secondi. Il riconoscimento del testo (OCR) sul dispositivo ti permette di cercare e copiare ogni "
           "parola senza internet, e i tuoi documenti non lasciano mai l'iPhone.\n\n"
           "FUNZIONI\n- Scansione dal vivo con rilevamento automatico dei bordi\n- OCR sul dispositivo: cerca, copia o "
           "ascolta il testo\n- Firma a mano su qualsiasi pagina\n- Tag, preferiti e ricerca in titoli e testo\n"
           "- Filtri: originale, migliorato, scala di grigi, bianco e nero\n- Sincronizzazione iCloud su tutti i "
           "dispositivi\n- Widget per la schermata Home\n\n"
           "Scansionare, taggare e organizzare è sempre gratis. Scanmuse Pro sblocca l'esportazione e la condivisione "
           "come PDF ricercabile o testo semplice.\n\nPRIVACY\nScanmuse non usa server propri. Nessuna pubblicità, "
           "nessuna analisi, nessun tracciamento."),
    "pl": ("Scanmuse zmienia iPhone'a w szybki i niezawodny skaner dokumentów.\n\n"
           "Skieruj aparat na paragon, notatkę, dowód lub umowę i w kilka sekund uzyskaj czysty skan. Rozpoznawanie "
           "tekstu (OCR) na urządzeniu pozwala wyszukiwać i kopiować każde słowo bez internetu, a dokumenty nigdy nie "
           "opuszczają iPhone'a.\n\n"
           "FUNKCJE\n- Skanowanie na żywo z automatycznym wykrywaniem krawędzi\n- OCR na urządzeniu: szukaj, kopiuj lub "
           "odsłuchaj tekst\n- Odręczny podpis na dowolnej stronie\n- Tagi, ulubione i wyszukiwanie w tytułach i "
           "tekście\n- Filtry: oryginał, poprawiony, skala szarości, czarno-biały\n- Synchronizacja iCloud na wszystkich "
           "urządzeniach\n- Widżet na ekranie głównym\n\n"
           "Skanowanie, tagowanie i porządkowanie jest zawsze bezpłatne. Scanmuse Pro odblokowuje eksport i "
           "udostępnianie jako PDF z wyszukiwaniem lub zwykły tekst.\n\nPRYWATNOŚĆ\nScanmuse nie korzysta z własnych "
           "serwerów. Bez reklam, analityki i śledzenia."),
    "nl-NL": ("Scanmuse verandert je iPhone in een snelle, betrouwbare documentscanner.\n\n"
              "Richt de camera op een bon, notitie, id-kaart of contract en krijg binnen enkele seconden een nette scan. "
              "Tekstherkenning (OCR) op het apparaat laat je elk woord doorzoeken en kopiëren zonder internet, en je "
              "documenten verlaten je iPhone niet.\n\n"
              "FUNCTIES\n- Live scannen met automatische randdetectie\n- OCR op het apparaat: zoeken, kopiëren of laten "
              "voorlezen\n- Handgeschreven handtekening op elke pagina\n- Tags, favorieten en zoeken in titels en "
              "tekst\n- Beeldfilters: origineel, verbeterd, grijstinten, zwart-wit\n- iCloud-synchronisatie op al je "
              "apparaten\n- Widget voor het beginscherm\n\n"
              "Scannen, taggen en ordenen is altijd gratis. Met Scanmuse Pro exporteer en deel je documenten als "
              "doorzoekbare pdf of platte tekst.\n\nPRIVACY\nScanmuse gebruikt geen eigen servers. Geen advertenties, "
              "geen analyse, geen tracking."),
    "ja": ("Scanmuseは、iPhoneを高速で信頼できる書類スキャナーに変えます。\n\n"
           "レシート、メモ、本人確認書類、契約書にカメラを向けるだけで、数秒できれいなスキャンが完成。端末内のOCR(文字認識)で"
           "すべての文字を検索・コピーでき、インターネットは不要。書類が端末の外に出ることはありません。\n\n"
           "主な機能\n・自動で端を検出するライブスキャン\n・端末内OCR:検索、コピー、読み上げ\n・どのページにも手書き署名を追加\n"
           "・タグ、お気に入り、タイトルと本文の検索\n・画像フィルタ:オリジナル、補正、グレースケール、白黒\n"
           "・iCloudですべてのデバイスに同期\n・ホーム画面ウィジェット\n\n"
           "スキャン、タグ付け、整理はずっと無料。Scanmuse Proで、検索可能なPDFやテキストとして書き出し・共有できます。\n\n"
           "プライバシー\nScanmuseは独自のサーバーを使用しません。広告、解析、トラッキングはありません。"),
    "ko": ("Scanmuse는 iPhone을 빠르고 믿을 수 있는 문서 스캐너로 바꿔 줍니다.\n\n"
           "영수증, 메모, 신분증, 계약서에 카메라를 대면 몇 초 만에 깔끔하게 스캔됩니다. 기기 내 OCR(문자 인식)로 모든 단어를 "
           "검색하고 복사할 수 있으며, 인터넷이 필요 없고 문서는 기기 밖으로 나가지 않습니다.\n\n"
           "주요 기능\n- 자동 가장자리 인식 라이브 스캔\n- 기기 내 OCR: 검색, 복사, 음성 읽기\n- 모든 페이지에 손글씨 서명 추가\n"
           "- 태그, 즐겨찾기, 제목 및 본문 검색\n- 이미지 필터: 원본, 보정, 흑백 톤, 흑백\n- iCloud로 모든 기기에 동기화\n"
           "- 홈 화면 위젯\n\n"
           "스캔, 태그, 정리는 언제나 무료입니다. Scanmuse Pro로 검색 가능한 PDF 또는 텍스트로 내보내고 공유하세요.\n\n"
           "개인정보 보호\nScanmuse는 자체 서버를 사용하지 않습니다. 광고, 분석, 추적이 없습니다."),
}
# fr-CA shares fr-FR copy (Canadian French differs only in storefront keywords).
DESC["fr-CA"] = DESC["fr-FR"]

LEGAL_LABELS = {
    "tr": ("Gizlilik Politikası", "Kullanım Koşulları (EULA)", "KOŞULLAR VE GİZLİLİK"),
    "ru": ("Политика конфиденциальности", "Условия использования (EULA)", "УСЛОВИЯ И КОНФИДЕНЦИАЛЬНОСТЬ"),
    "uk": ("Політика конфіденційності", "Умови використання (EULA)", "УМОВИ Й КОНФІДЕНЦІЙНІСТЬ"),
    "pt-BR": ("Política de Privacidade", "Termos de Uso (EULA)", "TERMOS E PRIVACIDADE"),
    "es-MX": ("Política de privacidad", "Términos de uso (EULA)", "TÉRMINOS Y PRIVACIDAD"),
    "es-ES": ("Política de privacidad", "Términos de uso (EULA)", "TÉRMINOS Y PRIVACIDAD"),
    "de-DE": ("Datenschutzerklärung", "Nutzungsbedingungen (EULA)", "BEDINGUNGEN & DATENSCHUTZ"),
    "fr-FR": ("Politique de confidentialité", "Conditions d'utilisation (EULA)", "CONDITIONS ET CONFIDENTIALITÉ"),
    "fr-CA": ("Politique de confidentialité", "Conditions d'utilisation (EULA)", "CONDITIONS ET CONFIDENTIALITÉ"),
    "sv": ("Integritetspolicy", "Användarvillkor (EULA)", "VILLKOR OCH INTEGRITET"),
    "ca": ("Política de privacitat", "Condicions d'ús (EULA)", "CONDICIONS I PRIVACITAT"),
    "it": ("Informativa sulla privacy", "Termini di utilizzo (EULA)", "TERMINI E PRIVACY"),
    "pl": ("Polityka prywatności", "Warunki użytkowania (EULA)", "WARUNKI I PRYWATNOŚĆ"),
    "nl-NL": ("Privacybeleid", "Gebruiksvoorwaarden (EULA)", "VOORWAARDEN & PRIVACY"),
    "ja": ("プライバシーポリシー", "利用規約 (EULA)", "利用規約とプライバシー"),
    "ko": ("개인정보 처리방침", "이용 약관 (EULA)", "약관 및 개인정보"),
}

# name, subtitle, keywords, promo, description-key. Keyword lists come from the Scanmuse study,
# minus translate/password/lock/handwriting words (not Scanmuse features) and minus any word that
# already appears in the same localization's name or subtitle.
_ROWS = {
    "en-US": (EN_NAME, "Scan Documents & Image to Text",
              "receipt,sign,signer,jpg,converter,photo,camera,doc,id,card,paper,copy,extract,notes,reader", EN_PROMO),
    "en-GB": (EN_NAME, "Scan Receipts, Sign, Copy Text",
              "document,jpg,converter,photo,image,camera,maker,doc,id,card,paper,extract,signer,notes,reader",
              EN_PROMO.replace("recognize", "recognise")),
    "en-AU": (EN_NAME, "Scan Documents & Sign Anything",
              "receipts,app,photos,pictures,picture,files,notes,print,reader,maker,text,image,jpg,converter", EN_PROMO),
    "en-CA": (EN_NAME, "Scan App: Sign & Copy Text",
              "receipt,signer,jpg,converter,photo,image,camera,doc,id,card,paper,extract,document,notes,reader",
              EN_PROMO),
    "ar-SA": (EN_NAME, "Scan Receipts, IDs & Contracts",
              "notes,files,print,share,reader,phone,mobile,batch,multipage,document,photo,jpg", EN_PROMO),
    "vi": (EN_NAME, "Pictures & Photos to Text",
           "picture,images,png,jpeg,convert,documents,pages,quick,crop,enhance,filter,receipt,sign", EN_PROMO),
    "zh-Hans": (EN_NAME, "E-Sign Contracts & Documents",
                "esign,initials,agreement,draw,autograph,signed,receipt,photo,jpg,camera,text,scan", EN_PROMO),
    "zh-Hant": (EN_NAME, "Searchable Docs & Text Capture",
                "recognition,recognize,extractor,words,letters,language,languages,offline,scanning,scanned,copy,sign",
                EN_PROMO),
    "tr": (f"{BRAND}: PDF Belge Tarayıcı", "Tarama, OCR Metin Tanıma, İmza",
           "scanner,tara,evrak,fiş,kimlik,fotoğraf,fotoğraftan,metne,resim,yazı,jpg,kopyala,etiket",
           "Belgeleri saniyeler içinde PDF olarak tarayın, cihaz üzerinde OCR ile metni kopyalayın ve imzalayın. "
           "Reklam ve izleme yok; kitaplık yalnızca iCloud'unuzla eşitlenir."),
    "ru": (f"{BRAND}: Сканер документов", "PDF, скан текста и подпись",
           "сканирование,чек,фото,jpg,паспорт,камера,копировать",
           "Сканируйте документы в PDF за секунды, копируйте текст с помощью OCR на устройстве и подписывайте. "
           "Без рекламы и слежки: синхронизация только через ваш iCloud."),
    "uk": (f"{BRAND}: Сканер документів", "PDF, текст із фото, підпис",
           "сканування,чек,паспорт,jpg,камера,копіювати",
           "Скануйте документи в PDF за секунди, копіюйте текст за допомогою OCR на пристрої та підписуйте. "
           "Без реклами й стеження: бібліотека синхронізується лише через ваш iCloud."),
    "pt-BR": (f"{BRAND}: Escanear Documentos", "Digitalizar PDF, Assinar e OCR",
              "scanner,texto,imagem,foto,assinatura,recibo,nota,fiscal,rg,cnh,jpg,converter,copiar",
              "Digitalize documentos em PDF em segundos, copie texto com OCR no aparelho e assine tudo. Sem anúncios "
              "nem rastreamento: sua biblioteca sincroniza só pelo seu iCloud."),
    "es-MX": (f"{BRAND}: Escáner PDF y OCR", "Escanear documentos y firmar",
              "escaner,scanner,fotos,texto,imagen,firma,recibo,factura,convertir,jpg,cámara,ine,copiar,etiquetas",
              "Escanea documentos a PDF en segundos, copia texto con OCR en tu iPhone y firma lo que sea. Sin "
              "anuncios ni rastreo: tu biblioteca se sincroniza solo con tu iCloud."),
    "es-ES": (f"{BRAND}: Escanear Documentos", "Escáner PDF, OCR y firmar",
              "escaner,fotos,texto,imagen,firma,recibo,factura,dni,convertir,jpg,cámara,scanner,copiar,etiquetas",
              "Escanea documentos a PDF en segundos, copia texto con OCR en tu iPhone y firma lo que sea. Sin "
              "anuncios ni rastreo: tu biblioteca se sincroniza solo con tu iCloud."),
    "de-DE": (f"{BRAND}: Dokumente Scannen", "PDF Scanner, OCR, Unterschrift",
              "kassenbon,beleg,unterschreiben,erstellen,app,foto,bild,jpg,umwandeln,texterkennung,ausweis,kopieren",
              "Scanne Dokumente in Sekunden als PDF, kopiere Text per OCR auf dem iPhone und unterschreibe. "
              "Keine Werbung, kein Tracking: Sync nur über dein iCloud."),
    "fr-FR": (f"{BRAND}: Scanner PDF Document", "Scan, OCR, Signature & Texte",
              "numériser,image,photo,jpg,fichier,doc,reçu,facture,identité,carte,convertisseur,caméra,copier",
              "Numérisez vos documents en PDF en quelques secondes, copiez le texte par OCR et signez. "
              "Ni pub ni suivi : synchronisation uniquement via votre iCloud."),
    "fr-CA": (f"{BRAND}: Numériser Documents", "Scanneur PDF, OCR et signature",
              "texte,image,photo,reçu,facture,carte,jpg,convertisseur,caméra,fichier,scan,numérisation,copier",
              "Numérisez vos documents en PDF en quelques secondes, copiez le texte par OCR et signez. "
              "Ni pub ni suivi : synchronisation uniquement via votre iCloud."),
    "sv": (f"{BRAND}: Skanna dokument", "PDF skanner, OCR och signatur",
           "skanning,bilder,bild,text,kvitto,id,kort,foto,kamera,jpg,konvertera,fil,kopiera,taggar",
           "Skanna dokument till PDF på några sekunder, kopiera text med OCR direkt i iPhone och signera. Inga "
           "annonser, ingen spårning: ditt bibliotek synkas bara via ditt iCloud."),
    "ca": (f"{BRAND}: Escanejar Documents", "Escàner PDF, OCR i signatura",
           "escaneig,imatge,foto,rebut,càmera,signar,escaneja,fitxer,targeta,arxiu,lector,copiar,etiquetes",
           "Escaneja documents a PDF en segons, copia text amb OCR a l'iPhone i signa. Sense anuncis ni seguiment: "
           "la biblioteca se sincronitza només amb el teu iCloud."),
    "it": (f"{BRAND}: Scansione Documenti", "Scanner PDF, OCR testo e firma",
           "scansiona,foto,immagine,ricevuta,scontrino,fattura,identità,carta,jpg,convertitore,scan,app,copia",
           "Scansiona documenti in PDF in pochi secondi, copia il testo con l'OCR sull'iPhone e firma. "
           "Niente pubblicità né tracciamento: sync solo con il tuo iCloud."),
    "pl": (f"{BRAND}: Skaner dokumentów", "Skanuj PDF, tekst OCR, podpis",
           "skanowanie,dokument,zdjęcia,zdjęcie,paragon,dowód,jpg,konwerter,faktura,skan,kopiuj,tagi",
           "Skanuj dokumenty do PDF w kilka sekund, kopiuj tekst przez OCR na iPhonie i podpisuj. Bez reklam i "
           "śledzenia: biblioteka synchronizuje się tylko przez Twoje iCloud."),
    "nl-NL": (f"{BRAND}: Documenten Scannen", "PDF Scanner, OCR, Ondertekenen",
              "scan,document,foto,tekst,bon,kassabon,handtekening,afbeelding,jpg,id,kopiëren,labels",
              "Scan documenten in enkele seconden naar PDF, kopieer tekst met OCR op je iPhone en onderteken. "
              "Geen advertenties of tracking: sync alleen via je iCloud."),
    "ja": (f"{BRAND}: 書類スキャン・PDFスキャナー", "写真から文字読み取り・OCR・署名",
           "アプリ,カメラ,画像,変換,レシート,文書,テキスト,認識,サイン,jpg,コピー",
           "書類を数秒でPDFにスキャン。端末内のOCRで文字をコピーし、署名もできます。広告もトラッキングもなく、"
           "ライブラリは自分のiCloudだけで同期します。"),
    "ko": (f"{BRAND}: 문서 스캔·PDF 스캐너", "사진 텍스트 추출, 문자 인식 OCR",
           "앱,서명,영수증,카메라,변환,이미지,jpg,스캐너앱,스캔앱,전자서명,복사",
           "문서를 몇 초 만에 PDF로 스캔하고, 기기 내 OCR로 텍스트를 복사하고, 서명하세요. 광고도 추적도 없으며 "
           "라이브러리는 내 iCloud로만 동기화됩니다."),
}


# "What's New" is required on every update (not on the first version). Kept short and generic.
WHATS_NEW = {
    "en": "Improved search, a refreshed library layout and stability fixes.",
    "tr": "Gelişmiş arama, yenilenen kitaplık düzeni ve kararlılık iyileştirmeleri.",
    "ru": "Улучшенный поиск, обновлённая библиотека и исправления стабильности.",
    "uk": "Покращений пошук, оновлена бібліотека та виправлення стабільності.",
    "pt": "Busca melhorada, biblioteca renovada e correções de estabilidade.",
    "es": "Búsqueda mejorada, biblioteca renovada y correcciones de estabilidad.",
    "de": "Verbesserte Suche, neue Bibliotheksansicht und Stabilitätsverbesserungen.",
    "fr": "Recherche améliorée, bibliothèque repensée et correctifs de stabilité.",
    "sv": "Bättre sökning, ny biblioteksvy och stabilitetsförbättringar.",
    "ca": "Cerca millorada, biblioteca renovada i correccions d'estabilitat.",
    "it": "Ricerca migliorata, libreria rinnovata e correzioni di stabilità.",
    "pl": "Lepsze wyszukiwanie, odświeżona biblioteka i poprawki stabilności.",
    "nl": "Betere zoekfunctie, vernieuwde bibliotheek en stabiliteitsverbeteringen.",
    "ja": "検索の改善、ライブラリ表示の刷新、安定性の向上。",
    "ko": "검색 개선, 새로워진 라이브러리 화면, 안정성 향상.",
}


def whats_new(locale: str) -> str:
    return WHATS_NEW.get(locale.split("-")[0], WHATS_NEW["en"])


def build() -> dict[str, dict[str, str]]:
    out = {}
    for locale, (name, subtitle, keywords, promo) in _ROWS.items():
        if locale in DESC:
            privacy, terms, header = LEGAL_LABELS[locale]
            desc = DESC[locale] + legal(privacy, terms, header)
        else:
            desc = en_desc(spell_recognise=locale in ("en-GB", "en-AU")) + legal()
        out[locale] = {"name": name, "subtitle": subtitle, "keywords": keywords, "promotionalText": promo,
                       "description": desc, "whatsNew": whats_new(locale), "supportUrl": SUPPORT_URL, "privacyPolicyUrl": PRIVACY_URL}
    return out


def words(text: str) -> set[str]:
    return {w.lower() for w in re.findall(r"[\w'’]+", text, flags=re.UNICODE) if len(w) > 1}


def validate(meta: dict[str, dict[str, str]]) -> list[str]:
    problems = []
    for loc, m in meta.items():
        if len(m["name"]) > 30:
            problems.append(f"{loc}: name {len(m['name'])} > 30")
        if len(m["subtitle"]) > 30:
            problems.append(f"{loc}: subtitle {len(m['subtitle'])} > 30")
        kb = len(m["keywords"].encode())
        if kb > 100:
            problems.append(f"{loc}: keywords {kb} bytes > 100")
        if len(m["promotionalText"]) > 170:
            problems.append(f"{loc}: promo {len(m['promotionalText'])} > 170")
        if len(m["description"]) > 4000:
            problems.append(f"{loc}: description {len(m['description'])} > 4000")
        kws = m["keywords"].split(",")
        if len(set(kws)) != len(kws):
            problems.append(f"{loc}: duplicate keyword inside the keyword field")
        if " " in m["keywords"] or m["keywords"].endswith(",") or m["keywords"].startswith(","):
            problems.append(f"{loc}: keywords must be comma-separated without spaces")
        overlap = {k for k in kws if k.lower() in words(m["name"]) | words(m["subtitle"])}
        if overlap:
            problems.append(f"{loc}: keywords repeat name/subtitle words {sorted(overlap)}")
        sub_overlap = (words(m["name"]) & words(m["subtitle"])) - {BRAND.lower()}
        if sub_overlap:
            problems.append(f"{loc}: subtitle repeats name words {sorted(sub_overlap)} (wasted slot)")
        for field in ("name", "subtitle", "keywords", "promotionalText"):
            if re.search(r"\bfree\b|gratis|бесплат|безкошт|kostenlos|ücretsiz|gratuit|無料|무료", m[field], re.I):
                problems.append(f"{loc}: {field} contains a pricing word (Guideline 2.3.7)")
        if EULA_URL not in m["description"] or PRIVACY_URL not in m["description"]:
            problems.append(f"{loc}: description is missing the EULA/Privacy links Apple requires")
    return problems


if __name__ == "__main__":
    data = build()
    issues = validate(data)
    if "--json" in sys.argv:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(f"{'locale':8} {'name':>4} {'sub':>4} {'kw(B)':>6} {'promo':>6} {'desc':>5}")
        for loc, m in data.items():
            print(f"{loc:8} {len(m['name']):>4} {len(m['subtitle']):>4} {len(m['keywords'].encode()):>6} "
                  f"{len(m['promotionalText']):>6} {len(m['description']):>5}")
        print()
        print("OK: all limits satisfied" if not issues else "PROBLEMS:\n  " + "\n  ".join(issues))
    sys.exit(1 if issues else 0)
