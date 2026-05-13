import 'country_info.dart';

/// Local offline world countries dataset with multilingual aliases.
class CountryDatabase {
  static const List<CountryInfo> countries = [
    // GCC + MENA
    CountryInfo(countryCode: 'SA', englishName: 'Saudi Arabia', arabicName: 'السعودية', currencyCode: 'SAR', currencyName: 'Saudi Riyal', flagEmoji: '🇸🇦', searchTerms: ['ksa', 'saudi', 'riyadh', 'سعودية']),
    CountryInfo(countryCode: 'AE', englishName: 'United Arab Emirates', arabicName: 'الإمارات', currencyCode: 'AED', currencyName: 'UAE Dirham', flagEmoji: '🇦🇪', searchTerms: ['uae', 'emirates', 'dubai', 'abudhabi', 'الامارات']),
    CountryInfo(countryCode: 'KW', englishName: 'Kuwait', arabicName: 'الكويت', currencyCode: 'KWD', currencyName: 'Kuwaiti Dinar', flagEmoji: '🇰🇼'),
    CountryInfo(countryCode: 'QA', englishName: 'Qatar', arabicName: 'قطر', currencyCode: 'QAR', currencyName: 'Qatari Riyal', flagEmoji: '🇶🇦'),
    CountryInfo(countryCode: 'BH', englishName: 'Bahrain', arabicName: 'البحرين', currencyCode: 'BHD', currencyName: 'Bahraini Dinar', flagEmoji: '🇧🇭'),
    CountryInfo(countryCode: 'OM', englishName: 'Oman', arabicName: 'عمان', currencyCode: 'OMR', currencyName: 'Omani Rial', flagEmoji: '🇴🇲'),
    CountryInfo(countryCode: 'YE', englishName: 'Yemen', arabicName: 'اليمن', currencyCode: 'YER', currencyName: 'Yemeni Rial', flagEmoji: '🇾🇪'),
    CountryInfo(countryCode: 'EG', englishName: 'Egypt', arabicName: 'مصر', currencyCode: 'EGP', currencyName: 'Egyptian Pound', flagEmoji: '🇪🇬'),
    CountryInfo(countryCode: 'JO', englishName: 'Jordan', arabicName: 'الأردن', currencyCode: 'JOD', currencyName: 'Jordanian Dinar', flagEmoji: '🇯🇴'),
    CountryInfo(countryCode: 'LB', englishName: 'Lebanon', arabicName: 'لبنان', currencyCode: 'LBP', currencyName: 'Lebanese Pound', flagEmoji: '🇱🇧'),
    CountryInfo(countryCode: 'SY', englishName: 'Syria', arabicName: 'سوريا', currencyCode: 'SYP', currencyName: 'Syrian Pound', flagEmoji: '🇸🇾'),
    CountryInfo(countryCode: 'IQ', englishName: 'Iraq', arabicName: 'العراق', currencyCode: 'IQD', currencyName: 'Iraqi Dinar', flagEmoji: '🇮🇶'),
    CountryInfo(countryCode: 'PS', englishName: 'Palestine', arabicName: 'فلسطين', currencyCode: 'ILS', currencyName: 'Israeli New Shekel', flagEmoji: '🇵🇸', searchTerms: ['palestinian', 'فلسطين']),
    CountryInfo(countryCode: 'IL', englishName: 'Israel', arabicName: 'إسرائيل', currencyCode: 'ILS', currencyName: 'Israeli New Shekel', flagEmoji: '🇮🇱'),
    CountryInfo(countryCode: 'TR', englishName: 'Turkey', arabicName: 'تركيا', currencyCode: 'TRY', currencyName: 'Turkish Lira', flagEmoji: '🇹🇷', searchTerms: ['turkiye', 'turk', 'istanbul']),
    CountryInfo(countryCode: 'IR', englishName: 'Iran', arabicName: 'إيران', currencyCode: 'IRR', currencyName: 'Iranian Rial', flagEmoji: '🇮🇷'),

    // East / South / Southeast Asia
    CountryInfo(countryCode: 'TH', englishName: 'Thailand', arabicName: 'تايلند', currencyCode: 'THB', currencyName: 'Thai Baht', flagEmoji: '🇹🇭', searchTerms: ['thai', 'bangkok', 'تايلاند']),
    CountryInfo(countryCode: 'JP', englishName: 'Japan', arabicName: 'اليابان', currencyCode: 'JPY', currencyName: 'Japanese Yen', flagEmoji: '🇯🇵', searchTerms: ['tokyo']),
    CountryInfo(countryCode: 'CN', englishName: 'China', arabicName: 'الصين', currencyCode: 'CNY', currencyName: 'Chinese Yuan', flagEmoji: '🇨🇳'),
    CountryInfo(countryCode: 'KR', englishName: 'South Korea', arabicName: 'كوريا الجنوبية', currencyCode: 'KRW', currencyName: 'South Korean Won', flagEmoji: '🇰🇷', searchTerms: ['korea', 'seoul']),
    CountryInfo(countryCode: 'KP', englishName: 'North Korea', arabicName: 'كوريا الشمالية', currencyCode: 'KPW', currencyName: 'North Korean Won', flagEmoji: '🇰🇵'),
    CountryInfo(countryCode: 'TW', englishName: 'Taiwan', arabicName: 'تايوان', currencyCode: 'TWD', currencyName: 'New Taiwan Dollar', flagEmoji: '🇹🇼'),
    CountryInfo(countryCode: 'HK', englishName: 'Hong Kong', arabicName: 'هونغ كونغ', currencyCode: 'HKD', currencyName: 'Hong Kong Dollar', flagEmoji: '🇭🇰'),
    CountryInfo(countryCode: 'MO', englishName: 'Macao', arabicName: 'ماكاو', currencyCode: 'MOP', currencyName: 'Macanese Pataca', flagEmoji: '🇲🇴'),
    CountryInfo(countryCode: 'VN', englishName: 'Vietnam', arabicName: 'فيتنام', currencyCode: 'VND', currencyName: 'Vietnamese Dong', flagEmoji: '🇻🇳'),
    CountryInfo(countryCode: 'ID', englishName: 'Indonesia', arabicName: 'إندونيسيا', currencyCode: 'IDR', currencyName: 'Indonesian Rupiah', flagEmoji: '🇮🇩'),
    CountryInfo(countryCode: 'MY', englishName: 'Malaysia', arabicName: 'ماليزيا', currencyCode: 'MYR', currencyName: 'Malaysian Ringgit', flagEmoji: '🇲🇾'),
    CountryInfo(countryCode: 'SG', englishName: 'Singapore', arabicName: 'سنغافورة', currencyCode: 'SGD', currencyName: 'Singapore Dollar', flagEmoji: '🇸🇬'),
    CountryInfo(countryCode: 'PH', englishName: 'Philippines', arabicName: 'الفلبين', currencyCode: 'PHP', currencyName: 'Philippine Peso', flagEmoji: '🇵🇭'),
    CountryInfo(countryCode: 'BN', englishName: 'Brunei', arabicName: 'بروناي', currencyCode: 'BND', currencyName: 'Brunei Dollar', flagEmoji: '🇧🇳'),
    CountryInfo(countryCode: 'KH', englishName: 'Cambodia', arabicName: 'كمبوديا', currencyCode: 'KHR', currencyName: 'Cambodian Riel', flagEmoji: '🇰🇭'),
    CountryInfo(countryCode: 'LA', englishName: 'Laos', arabicName: 'لاوس', currencyCode: 'LAK', currencyName: 'Lao Kip', flagEmoji: '🇱🇦'),
    CountryInfo(countryCode: 'MM', englishName: 'Myanmar', arabicName: 'ميانمار', currencyCode: 'MMK', currencyName: 'Myanmar Kyat', flagEmoji: '🇲🇲'),
    CountryInfo(countryCode: 'TL', englishName: 'Timor-Leste', arabicName: 'تيمور الشرقية', currencyCode: 'USD', currencyName: 'US Dollar', flagEmoji: '🇹🇱'),
    CountryInfo(countryCode: 'IN', englishName: 'India', arabicName: 'الهند', currencyCode: 'INR', currencyName: 'Indian Rupee', flagEmoji: '🇮🇳'),
    CountryInfo(countryCode: 'PK', englishName: 'Pakistan', arabicName: 'باكستان', currencyCode: 'PKR', currencyName: 'Pakistani Rupee', flagEmoji: '🇵🇰'),
    CountryInfo(countryCode: 'BD', englishName: 'Bangladesh', arabicName: 'بنغلاديش', currencyCode: 'BDT', currencyName: 'Bangladeshi Taka', flagEmoji: '🇧🇩'),
    CountryInfo(countryCode: 'LK', englishName: 'Sri Lanka', arabicName: 'سريلانكا', currencyCode: 'LKR', currencyName: 'Sri Lankan Rupee', flagEmoji: '🇱🇰'),
    CountryInfo(countryCode: 'NP', englishName: 'Nepal', arabicName: 'نيبال', currencyCode: 'NPR', currencyName: 'Nepalese Rupee', flagEmoji: '🇳🇵'),
    CountryInfo(countryCode: 'BT', englishName: 'Bhutan', arabicName: 'بوتان', currencyCode: 'BTN', currencyName: 'Bhutanese Ngultrum', flagEmoji: '🇧🇹'),
    CountryInfo(countryCode: 'MV', englishName: 'Maldives', arabicName: 'المالديف', currencyCode: 'MVR', currencyName: 'Maldivian Rufiyaa', flagEmoji: '🇲🇻'),
    CountryInfo(countryCode: 'AF', englishName: 'Afghanistan', arabicName: 'أفغانستان', currencyCode: 'AFN', currencyName: 'Afghan Afghani', flagEmoji: '🇦🇫'),
    CountryInfo(countryCode: 'KZ', englishName: 'Kazakhstan', arabicName: 'كازاخستان', currencyCode: 'KZT', currencyName: 'Kazakhstani Tenge', flagEmoji: '🇰🇿'),
    CountryInfo(countryCode: 'UZ', englishName: 'Uzbekistan', arabicName: 'أوزبكستان', currencyCode: 'UZS', currencyName: 'Uzbekistani Som', flagEmoji: '🇺🇿'),
    CountryInfo(countryCode: 'TM', englishName: 'Turkmenistan', arabicName: 'تركمانستان', currencyCode: 'TMT', currencyName: 'Turkmenistani Manat', flagEmoji: '🇹🇲'),
    CountryInfo(countryCode: 'KG', englishName: 'Kyrgyzstan', arabicName: 'قيرغيزستان', currencyCode: 'KGS', currencyName: 'Kyrgyzstani Som', flagEmoji: '🇰🇬'),
    CountryInfo(countryCode: 'TJ', englishName: 'Tajikistan', arabicName: 'طاجيكستان', currencyCode: 'TJS', currencyName: 'Tajikistani Somoni', flagEmoji: '🇹🇯'),
    CountryInfo(countryCode: 'MN', englishName: 'Mongolia', arabicName: 'منغوليا', currencyCode: 'MNT', currencyName: 'Mongolian Tugrik', flagEmoji: '🇲🇳'),

    // Europe
    CountryInfo(countryCode: 'GB', englishName: 'United Kingdom', arabicName: 'المملكة المتحدة', currencyCode: 'GBP', currencyName: 'British Pound', flagEmoji: '🇬🇧', searchTerms: ['uk', 'britain', 'england', 'london']),
    CountryInfo(countryCode: 'IE', englishName: 'Ireland', arabicName: 'أيرلندا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇮🇪'),
    CountryInfo(countryCode: 'FR', englishName: 'France', arabicName: 'فرنسا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇫🇷'),
    CountryInfo(countryCode: 'DE', englishName: 'Germany', arabicName: 'ألمانيا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇩🇪'),
    CountryInfo(countryCode: 'IT', englishName: 'Italy', arabicName: 'إيطاليا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇮🇹'),
    CountryInfo(countryCode: 'ES', englishName: 'Spain', arabicName: 'إسبانيا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇪🇸'),
    CountryInfo(countryCode: 'PT', englishName: 'Portugal', arabicName: 'البرتغال', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇵🇹'),
    CountryInfo(countryCode: 'NL', englishName: 'Netherlands', arabicName: 'هولندا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇳🇱'),
    CountryInfo(countryCode: 'BE', englishName: 'Belgium', arabicName: 'بلجيكا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇧🇪'),
    CountryInfo(countryCode: 'LU', englishName: 'Luxembourg', arabicName: 'لوكسمبورغ', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇱🇺'),
    CountryInfo(countryCode: 'CH', englishName: 'Switzerland', arabicName: 'سويسرا', currencyCode: 'CHF', currencyName: 'Swiss Franc', flagEmoji: '🇨🇭'),
    CountryInfo(countryCode: 'AT', englishName: 'Austria', arabicName: 'النمسا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇦🇹'),
    CountryInfo(countryCode: 'SE', englishName: 'Sweden', arabicName: 'السويد', currencyCode: 'SEK', currencyName: 'Swedish Krona', flagEmoji: '🇸🇪'),
    CountryInfo(countryCode: 'NO', englishName: 'Norway', arabicName: 'النرويج', currencyCode: 'NOK', currencyName: 'Norwegian Krone', flagEmoji: '🇳🇴'),
    CountryInfo(countryCode: 'DK', englishName: 'Denmark', arabicName: 'الدنمارك', currencyCode: 'DKK', currencyName: 'Danish Krone', flagEmoji: '🇩🇰'),
    CountryInfo(countryCode: 'FI', englishName: 'Finland', arabicName: 'فنلندا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇫🇮'),
    CountryInfo(countryCode: 'IS', englishName: 'Iceland', arabicName: 'آيسلندا', currencyCode: 'ISK', currencyName: 'Icelandic Krona', flagEmoji: '🇮🇸'),
    CountryInfo(countryCode: 'PL', englishName: 'Poland', arabicName: 'بولندا', currencyCode: 'PLN', currencyName: 'Polish Zloty', flagEmoji: '🇵🇱'),
    CountryInfo(countryCode: 'CZ', englishName: 'Czechia', arabicName: 'التشيك', currencyCode: 'CZK', currencyName: 'Czech Koruna', flagEmoji: '🇨🇿', searchTerms: ['czech republic']),
    CountryInfo(countryCode: 'SK', englishName: 'Slovakia', arabicName: 'سلوفاكيا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇸🇰'),
    CountryInfo(countryCode: 'HU', englishName: 'Hungary', arabicName: 'المجر', currencyCode: 'HUF', currencyName: 'Hungarian Forint', flagEmoji: '🇭🇺'),
    CountryInfo(countryCode: 'RO', englishName: 'Romania', arabicName: 'رومانيا', currencyCode: 'RON', currencyName: 'Romanian Leu', flagEmoji: '🇷🇴'),
    CountryInfo(countryCode: 'BG', englishName: 'Bulgaria', arabicName: 'بلغاريا', currencyCode: 'BGN', currencyName: 'Bulgarian Lev', flagEmoji: '🇧🇬'),
    CountryInfo(countryCode: 'GR', englishName: 'Greece', arabicName: 'اليونان', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇬🇷'),
    CountryInfo(countryCode: 'HR', englishName: 'Croatia', arabicName: 'كرواتيا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇭🇷'),
    CountryInfo(countryCode: 'SI', englishName: 'Slovenia', arabicName: 'سلوفينيا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇸🇮'),
    CountryInfo(countryCode: 'RS', englishName: 'Serbia', arabicName: 'صربيا', currencyCode: 'RSD', currencyName: 'Serbian Dinar', flagEmoji: '🇷🇸'),
    CountryInfo(countryCode: 'BA', englishName: 'Bosnia and Herzegovina', arabicName: 'البوسنة والهرسك', currencyCode: 'BAM', currencyName: 'Convertible Mark', flagEmoji: '🇧🇦', searchTerms: ['bosnia']),
    CountryInfo(countryCode: 'ME', englishName: 'Montenegro', arabicName: 'الجبل الأسود', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇲🇪'),
    CountryInfo(countryCode: 'MK', englishName: 'North Macedonia', arabicName: 'مقدونيا الشمالية', currencyCode: 'MKD', currencyName: 'Macedonian Denar', flagEmoji: '🇲🇰', searchTerms: ['macedonia']),
    CountryInfo(countryCode: 'AL', englishName: 'Albania', arabicName: 'ألبانيا', currencyCode: 'ALL', currencyName: 'Albanian Lek', flagEmoji: '🇦🇱'),
    CountryInfo(countryCode: 'MD', englishName: 'Moldova', arabicName: 'مولدوفا', currencyCode: 'MDL', currencyName: 'Moldovan Leu', flagEmoji: '🇲🇩'),
    CountryInfo(countryCode: 'UA', englishName: 'Ukraine', arabicName: 'أوكرانيا', currencyCode: 'UAH', currencyName: 'Ukrainian Hryvnia', flagEmoji: '🇺🇦'),
    CountryInfo(countryCode: 'BY', englishName: 'Belarus', arabicName: 'بيلاروسيا', currencyCode: 'BYN', currencyName: 'Belarusian Ruble', flagEmoji: '🇧🇾'),
    CountryInfo(countryCode: 'LT', englishName: 'Lithuania', arabicName: 'ليتوانيا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇱🇹'),
    CountryInfo(countryCode: 'LV', englishName: 'Latvia', arabicName: 'لاتفيا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇱🇻'),
    CountryInfo(countryCode: 'EE', englishName: 'Estonia', arabicName: 'إستونيا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇪🇪'),
    CountryInfo(countryCode: 'RU', englishName: 'Russia', arabicName: 'روسيا', currencyCode: 'RUB', currencyName: 'Russian Ruble', flagEmoji: '🇷🇺'),
    CountryInfo(countryCode: 'VA', englishName: 'Vatican City', arabicName: 'الفاتيكان', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇻🇦', searchTerms: ['holy see']),
    CountryInfo(countryCode: 'AD', englishName: 'Andorra', arabicName: 'أندورا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇦🇩'),
    CountryInfo(countryCode: 'MC', englishName: 'Monaco', arabicName: 'موناكو', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇲🇨'),
    CountryInfo(countryCode: 'SM', englishName: 'San Marino', arabicName: 'سان مارينو', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇸🇲'),
    CountryInfo(countryCode: 'LI', englishName: 'Liechtenstein', arabicName: 'ليختنشتاين', currencyCode: 'CHF', currencyName: 'Swiss Franc', flagEmoji: '🇱🇮'),
    CountryInfo(countryCode: 'MT', englishName: 'Malta', arabicName: 'مالطا', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇲🇹'),
    CountryInfo(countryCode: 'CY', englishName: 'Cyprus', arabicName: 'قبرص', currencyCode: 'EUR', currencyName: 'Euro', flagEmoji: '🇨🇾'),

    // Americas
    CountryInfo(countryCode: 'US', englishName: 'United States', arabicName: 'الولايات المتحدة', currencyCode: 'USD', currencyName: 'US Dollar', flagEmoji: '🇺🇸', searchTerms: ['usa', 'america', 'us']),
    CountryInfo(countryCode: 'CA', englishName: 'Canada', arabicName: 'كندا', currencyCode: 'CAD', currencyName: 'Canadian Dollar', flagEmoji: '🇨🇦'),
    CountryInfo(countryCode: 'MX', englishName: 'Mexico', arabicName: 'المكسيك', currencyCode: 'MXN', currencyName: 'Mexican Peso', flagEmoji: '🇲🇽'),
    CountryInfo(countryCode: 'GT', englishName: 'Guatemala', arabicName: 'غواتيمالا', currencyCode: 'GTQ', currencyName: 'Guatemalan Quetzal', flagEmoji: '🇬🇹'),
    CountryInfo(countryCode: 'BZ', englishName: 'Belize', arabicName: 'بليز', currencyCode: 'BZD', currencyName: 'Belize Dollar', flagEmoji: '🇧🇿'),
    CountryInfo(countryCode: 'SV', englishName: 'El Salvador', arabicName: 'السلفادور', currencyCode: 'USD', currencyName: 'US Dollar', flagEmoji: '🇸🇻'),
    CountryInfo(countryCode: 'HN', englishName: 'Honduras', arabicName: 'هندوراس', currencyCode: 'HNL', currencyName: 'Honduran Lempira', flagEmoji: '🇭🇳'),
    CountryInfo(countryCode: 'NI', englishName: 'Nicaragua', arabicName: 'نيكاراغوا', currencyCode: 'NIO', currencyName: 'Nicaraguan Cordoba', flagEmoji: '🇳🇮'),
    CountryInfo(countryCode: 'CR', englishName: 'Costa Rica', arabicName: 'كوستاريكا', currencyCode: 'CRC', currencyName: 'Costa Rican Colon', flagEmoji: '🇨🇷'),
    CountryInfo(countryCode: 'PA', englishName: 'Panama', arabicName: 'بنما', currencyCode: 'PAB', currencyName: 'Panamanian Balboa', flagEmoji: '🇵🇦'),
    CountryInfo(countryCode: 'CU', englishName: 'Cuba', arabicName: 'كوبا', currencyCode: 'CUP', currencyName: 'Cuban Peso', flagEmoji: '🇨🇺'),
    CountryInfo(countryCode: 'DO', englishName: 'Dominican Republic', arabicName: 'جمهورية الدومينيكان', currencyCode: 'DOP', currencyName: 'Dominican Peso', flagEmoji: '🇩🇴'),
    CountryInfo(countryCode: 'HT', englishName: 'Haiti', arabicName: 'هايتي', currencyCode: 'HTG', currencyName: 'Haitian Gourde', flagEmoji: '🇭🇹'),
    CountryInfo(countryCode: 'JM', englishName: 'Jamaica', arabicName: 'جامايكا', currencyCode: 'JMD', currencyName: 'Jamaican Dollar', flagEmoji: '🇯🇲'),
    CountryInfo(countryCode: 'TT', englishName: 'Trinidad and Tobago', arabicName: 'ترينيداد وتوباغو', currencyCode: 'TTD', currencyName: 'Trinidad and Tobago Dollar', flagEmoji: '🇹🇹'),
    CountryInfo(countryCode: 'BS', englishName: 'Bahamas', arabicName: 'جزر البهاما', currencyCode: 'BSD', currencyName: 'Bahamian Dollar', flagEmoji: '🇧🇸'),
    CountryInfo(countryCode: 'BB', englishName: 'Barbados', arabicName: 'باربادوس', currencyCode: 'BBD', currencyName: 'Barbadian Dollar', flagEmoji: '🇧🇧'),
    CountryInfo(countryCode: 'AG', englishName: 'Antigua and Barbuda', arabicName: 'أنتيغوا وبربودا', currencyCode: 'XCD', currencyName: 'East Caribbean Dollar', flagEmoji: '🇦🇬'),
    CountryInfo(countryCode: 'DM', englishName: 'Dominica', arabicName: 'دومينيكا', currencyCode: 'XCD', currencyName: 'East Caribbean Dollar', flagEmoji: '🇩🇲'),
    CountryInfo(countryCode: 'GD', englishName: 'Grenada', arabicName: 'غرينادا', currencyCode: 'XCD', currencyName: 'East Caribbean Dollar', flagEmoji: '🇬🇩'),
    CountryInfo(countryCode: 'KN', englishName: 'Saint Kitts and Nevis', arabicName: 'سانت كيتس ونيفيس', currencyCode: 'XCD', currencyName: 'East Caribbean Dollar', flagEmoji: '🇰🇳'),
    CountryInfo(countryCode: 'LC', englishName: 'Saint Lucia', arabicName: 'سانت لوسيا', currencyCode: 'XCD', currencyName: 'East Caribbean Dollar', flagEmoji: '🇱🇨'),
    CountryInfo(countryCode: 'VC', englishName: 'Saint Vincent and the Grenadines', arabicName: 'سانت فنسنت والغرينادين', currencyCode: 'XCD', currencyName: 'East Caribbean Dollar', flagEmoji: '🇻🇨'),
    CountryInfo(countryCode: 'CO', englishName: 'Colombia', arabicName: 'كولومبيا', currencyCode: 'COP', currencyName: 'Colombian Peso', flagEmoji: '🇨🇴'),
    CountryInfo(countryCode: 'VE', englishName: 'Venezuela', arabicName: 'فنزويلا', currencyCode: 'VES', currencyName: 'Venezuelan Bolivar', flagEmoji: '🇻🇪'),
    CountryInfo(countryCode: 'GY', englishName: 'Guyana', arabicName: 'غيانا', currencyCode: 'GYD', currencyName: 'Guyanese Dollar', flagEmoji: '🇬🇾'),
    CountryInfo(countryCode: 'SR', englishName: 'Suriname', arabicName: 'سورينام', currencyCode: 'SRD', currencyName: 'Surinamese Dollar', flagEmoji: '🇸🇷'),
    CountryInfo(countryCode: 'EC', englishName: 'Ecuador', arabicName: 'الإكوادور', currencyCode: 'USD', currencyName: 'US Dollar', flagEmoji: '🇪🇨'),
    CountryInfo(countryCode: 'PE', englishName: 'Peru', arabicName: 'بيرو', currencyCode: 'PEN', currencyName: 'Peruvian Sol', flagEmoji: '🇵🇪'),
    CountryInfo(countryCode: 'BO', englishName: 'Bolivia', arabicName: 'بوليفيا', currencyCode: 'BOB', currencyName: 'Bolivian Boliviano', flagEmoji: '🇧🇴'),
    CountryInfo(countryCode: 'PY', englishName: 'Paraguay', arabicName: 'باراغواي', currencyCode: 'PYG', currencyName: 'Paraguayan Guarani', flagEmoji: '🇵🇾'),
    CountryInfo(countryCode: 'UY', englishName: 'Uruguay', arabicName: 'أوروغواي', currencyCode: 'UYU', currencyName: 'Uruguayan Peso', flagEmoji: '🇺🇾'),
    CountryInfo(countryCode: 'AR', englishName: 'Argentina', arabicName: 'الأرجنتين', currencyCode: 'ARS', currencyName: 'Argentine Peso', flagEmoji: '🇦🇷'),
    CountryInfo(countryCode: 'CL', englishName: 'Chile', arabicName: 'تشيلي', currencyCode: 'CLP', currencyName: 'Chilean Peso', flagEmoji: '🇨🇱'),
    CountryInfo(countryCode: 'BR', englishName: 'Brazil', arabicName: 'البرازيل', currencyCode: 'BRL', currencyName: 'Brazilian Real', flagEmoji: '🇧🇷'),

    // Africa
    CountryInfo(countryCode: 'DZ', englishName: 'Algeria', arabicName: 'الجزائر', currencyCode: 'DZD', currencyName: 'Algerian Dinar', flagEmoji: '🇩🇿'),
    CountryInfo(countryCode: 'MA', englishName: 'Morocco', arabicName: 'المغرب', currencyCode: 'MAD', currencyName: 'Moroccan Dirham', flagEmoji: '🇲🇦'),
    CountryInfo(countryCode: 'TN', englishName: 'Tunisia', arabicName: 'تونس', currencyCode: 'TND', currencyName: 'Tunisian Dinar', flagEmoji: '🇹🇳'),
    CountryInfo(countryCode: 'LY', englishName: 'Libya', arabicName: 'ليبيا', currencyCode: 'LYD', currencyName: 'Libyan Dinar', flagEmoji: '🇱🇾'),
    CountryInfo(countryCode: 'SD', englishName: 'Sudan', arabicName: 'السودان', currencyCode: 'SDG', currencyName: 'Sudanese Pound', flagEmoji: '🇸🇩'),
    CountryInfo(countryCode: 'SS', englishName: 'South Sudan', arabicName: 'جنوب السودان', currencyCode: 'SSP', currencyName: 'South Sudanese Pound', flagEmoji: '🇸🇸'),
    CountryInfo(countryCode: 'MR', englishName: 'Mauritania', arabicName: 'موريتانيا', currencyCode: 'MRU', currencyName: 'Mauritanian Ouguiya', flagEmoji: '🇲🇷'),
    CountryInfo(countryCode: 'DJ', englishName: 'Djibouti', arabicName: 'جيبوتي', currencyCode: 'DJF', currencyName: 'Djiboutian Franc', flagEmoji: '🇩🇯'),
    CountryInfo(countryCode: 'SO', englishName: 'Somalia', arabicName: 'الصومال', currencyCode: 'SOS', currencyName: 'Somali Shilling', flagEmoji: '🇸🇴'),
    CountryInfo(countryCode: 'ET', englishName: 'Ethiopia', arabicName: 'إثيوبيا', currencyCode: 'ETB', currencyName: 'Ethiopian Birr', flagEmoji: '🇪🇹'),
    CountryInfo(countryCode: 'ER', englishName: 'Eritrea', arabicName: 'إريتريا', currencyCode: 'ERN', currencyName: 'Eritrean Nakfa', flagEmoji: '🇪🇷'),
    CountryInfo(countryCode: 'KE', englishName: 'Kenya', arabicName: 'كينيا', currencyCode: 'KES', currencyName: 'Kenyan Shilling', flagEmoji: '🇰🇪'),
    CountryInfo(countryCode: 'UG', englishName: 'Uganda', arabicName: 'أوغندا', currencyCode: 'UGX', currencyName: 'Ugandan Shilling', flagEmoji: '🇺🇬'),
    CountryInfo(countryCode: 'TZ', englishName: 'Tanzania', arabicName: 'تنزانيا', currencyCode: 'TZS', currencyName: 'Tanzanian Shilling', flagEmoji: '🇹🇿'),
    CountryInfo(countryCode: 'RW', englishName: 'Rwanda', arabicName: 'رواندا', currencyCode: 'RWF', currencyName: 'Rwandan Franc', flagEmoji: '🇷🇼'),
    CountryInfo(countryCode: 'BI', englishName: 'Burundi', arabicName: 'بوروندي', currencyCode: 'BIF', currencyName: 'Burundian Franc', flagEmoji: '🇧🇮'),
    CountryInfo(countryCode: 'CD', englishName: 'Democratic Republic of the Congo', arabicName: 'جمهورية الكونغو الديمقراطية', currencyCode: 'CDF', currencyName: 'Congolese Franc', flagEmoji: '🇨🇩', searchTerms: ['drc', 'congo dr']),
    CountryInfo(countryCode: 'CG', englishName: 'Republic of the Congo', arabicName: 'جمهورية الكونغو', currencyCode: 'XAF', currencyName: 'Central African CFA Franc', flagEmoji: '🇨🇬', searchTerms: ['congo']),
    CountryInfo(countryCode: 'CF', englishName: 'Central African Republic', arabicName: 'جمهورية أفريقيا الوسطى', currencyCode: 'XAF', currencyName: 'Central African CFA Franc', flagEmoji: '🇨🇫'),
    CountryInfo(countryCode: 'CM', englishName: 'Cameroon', arabicName: 'الكاميرون', currencyCode: 'XAF', currencyName: 'Central African CFA Franc', flagEmoji: '🇨🇲'),
    CountryInfo(countryCode: 'GA', englishName: 'Gabon', arabicName: 'الغابون', currencyCode: 'XAF', currencyName: 'Central African CFA Franc', flagEmoji: '🇬🇦'),
    CountryInfo(countryCode: 'GQ', englishName: 'Equatorial Guinea', arabicName: 'غينيا الاستوائية', currencyCode: 'XAF', currencyName: 'Central African CFA Franc', flagEmoji: '🇬🇶'),
    CountryInfo(countryCode: 'TD', englishName: 'Chad', arabicName: 'تشاد', currencyCode: 'XAF', currencyName: 'Central African CFA Franc', flagEmoji: '🇹🇩'),
    CountryInfo(countryCode: 'NG', englishName: 'Nigeria', arabicName: 'نيجيريا', currencyCode: 'NGN', currencyName: 'Nigerian Naira', flagEmoji: '🇳🇬'),
    CountryInfo(countryCode: 'NE', englishName: 'Niger', arabicName: 'النيجر', currencyCode: 'XOF', currencyName: 'West African CFA Franc', flagEmoji: '🇳🇪'),
    CountryInfo(countryCode: 'ML', englishName: 'Mali', arabicName: 'مالي', currencyCode: 'XOF', currencyName: 'West African CFA Franc', flagEmoji: '🇲🇱'),
    CountryInfo(countryCode: 'SN', englishName: 'Senegal', arabicName: 'السنغال', currencyCode: 'XOF', currencyName: 'West African CFA Franc', flagEmoji: '🇸🇳'),
    CountryInfo(countryCode: 'GN', englishName: 'Guinea', arabicName: 'غينيا', currencyCode: 'GNF', currencyName: 'Guinean Franc', flagEmoji: '🇬🇳'),
    CountryInfo(countryCode: 'GW', englishName: 'Guinea-Bissau', arabicName: 'غينيا بيساو', currencyCode: 'XOF', currencyName: 'West African CFA Franc', flagEmoji: '🇬🇼'),
    CountryInfo(countryCode: 'SL', englishName: 'Sierra Leone', arabicName: 'سيراليون', currencyCode: 'SLE', currencyName: 'Sierra Leonean Leone', flagEmoji: '🇸🇱'),
    CountryInfo(countryCode: 'LR', englishName: 'Liberia', arabicName: 'ليبيريا', currencyCode: 'LRD', currencyName: 'Liberian Dollar', flagEmoji: '🇱🇷'),
    CountryInfo(countryCode: 'CI', englishName: "Cote d'Ivoire", arabicName: 'ساحل العاج', currencyCode: 'XOF', currencyName: 'West African CFA Franc', flagEmoji: '🇨🇮', searchTerms: ['ivory coast']),
    CountryInfo(countryCode: 'GH', englishName: 'Ghana', arabicName: 'غانا', currencyCode: 'GHS', currencyName: 'Ghanaian Cedi', flagEmoji: '🇬🇭'),
    CountryInfo(countryCode: 'TG', englishName: 'Togo', arabicName: 'توغو', currencyCode: 'XOF', currencyName: 'West African CFA Franc', flagEmoji: '🇹🇬'),
    CountryInfo(countryCode: 'BJ', englishName: 'Benin', arabicName: 'بنين', currencyCode: 'XOF', currencyName: 'West African CFA Franc', flagEmoji: '🇧🇯'),
    CountryInfo(countryCode: 'BF', englishName: 'Burkina Faso', arabicName: 'بوركينا فاسو', currencyCode: 'XOF', currencyName: 'West African CFA Franc', flagEmoji: '🇧🇫'),
    CountryInfo(countryCode: 'GM', englishName: 'Gambia', arabicName: 'غامبيا', currencyCode: 'GMD', currencyName: 'Gambian Dalasi', flagEmoji: '🇬🇲'),
    CountryInfo(countryCode: 'CV', englishName: 'Cape Verde', arabicName: 'الرأس الأخضر', currencyCode: 'CVE', currencyName: 'Cape Verdean Escudo', flagEmoji: '🇨🇻'),
    CountryInfo(countryCode: 'ST', englishName: 'Sao Tome and Principe', arabicName: 'ساو تومي وبرينسيبي', currencyCode: 'STN', currencyName: 'Sao Tome and Principe Dobra', flagEmoji: '🇸🇹'),
    CountryInfo(countryCode: 'AO', englishName: 'Angola', arabicName: 'أنغولا', currencyCode: 'AOA', currencyName: 'Angolan Kwanza', flagEmoji: '🇦🇴'),
    CountryInfo(countryCode: 'ZM', englishName: 'Zambia', arabicName: 'زامبيا', currencyCode: 'ZMW', currencyName: 'Zambian Kwacha', flagEmoji: '🇿🇲'),
    CountryInfo(countryCode: 'ZW', englishName: 'Zimbabwe', arabicName: 'زيمبابوي', currencyCode: 'USD', currencyName: 'US Dollar', flagEmoji: '🇿🇼'),
    CountryInfo(countryCode: 'MW', englishName: 'Malawi', arabicName: 'ملاوي', currencyCode: 'MWK', currencyName: 'Malawian Kwacha', flagEmoji: '🇲🇼'),
    CountryInfo(countryCode: 'MZ', englishName: 'Mozambique', arabicName: 'موزمبيق', currencyCode: 'MZN', currencyName: 'Mozambican Metical', flagEmoji: '🇲🇿'),
    CountryInfo(countryCode: 'NA', englishName: 'Namibia', arabicName: 'ناميبيا', currencyCode: 'NAD', currencyName: 'Namibian Dollar', flagEmoji: '🇳🇦'),
    CountryInfo(countryCode: 'BW', englishName: 'Botswana', arabicName: 'بوتسوانا', currencyCode: 'BWP', currencyName: 'Botswana Pula', flagEmoji: '🇧🇼'),
    CountryInfo(countryCode: 'ZA', englishName: 'South Africa', arabicName: 'جنوب أفريقيا', currencyCode: 'ZAR', currencyName: 'South African Rand', flagEmoji: '🇿🇦'),
    CountryInfo(countryCode: 'LS', englishName: 'Lesotho', arabicName: 'ليسوتو', currencyCode: 'LSL', currencyName: 'Lesotho Loti', flagEmoji: '🇱🇸'),
    CountryInfo(countryCode: 'SZ', englishName: 'Eswatini', arabicName: 'إسواتيني', currencyCode: 'SZL', currencyName: 'Swazi Lilangeni', flagEmoji: '🇸🇿', searchTerms: ['swaziland']),
    CountryInfo(countryCode: 'MG', englishName: 'Madagascar', arabicName: 'مدغشقر', currencyCode: 'MGA', currencyName: 'Malagasy Ariary', flagEmoji: '🇲🇬'),
    CountryInfo(countryCode: 'MU', englishName: 'Mauritius', arabicName: 'موريشيوس', currencyCode: 'MUR', currencyName: 'Mauritian Rupee', flagEmoji: '🇲🇺'),
    CountryInfo(countryCode: 'SC', englishName: 'Seychelles', arabicName: 'سيشل', currencyCode: 'SCR', currencyName: 'Seychellois Rupee', flagEmoji: '🇸🇨'),
    CountryInfo(countryCode: 'KM', englishName: 'Comoros', arabicName: 'جزر القمر', currencyCode: 'KMF', currencyName: 'Comorian Franc', flagEmoji: '🇰🇲'),

    // Oceania
    CountryInfo(countryCode: 'AU', englishName: 'Australia', arabicName: 'أستراليا', currencyCode: 'AUD', currencyName: 'Australian Dollar', flagEmoji: '🇦🇺'),
    CountryInfo(countryCode: 'NZ', englishName: 'New Zealand', arabicName: 'نيوزيلندا', currencyCode: 'NZD', currencyName: 'New Zealand Dollar', flagEmoji: '🇳🇿'),
    CountryInfo(countryCode: 'PG', englishName: 'Papua New Guinea', arabicName: 'بابوا غينيا الجديدة', currencyCode: 'PGK', currencyName: 'Papua New Guinean Kina', flagEmoji: '🇵🇬'),
    CountryInfo(countryCode: 'FJ', englishName: 'Fiji', arabicName: 'فيجي', currencyCode: 'FJD', currencyName: 'Fijian Dollar', flagEmoji: '🇫🇯'),
    CountryInfo(countryCode: 'SB', englishName: 'Solomon Islands', arabicName: 'جزر سليمان', currencyCode: 'SBD', currencyName: 'Solomon Islands Dollar', flagEmoji: '🇸🇧'),
    CountryInfo(countryCode: 'VU', englishName: 'Vanuatu', arabicName: 'فانواتو', currencyCode: 'VUV', currencyName: 'Vanuatu Vatu', flagEmoji: '🇻🇺'),
    CountryInfo(countryCode: 'WS', englishName: 'Samoa', arabicName: 'ساموا', currencyCode: 'WST', currencyName: 'Samoan Tala', flagEmoji: '🇼🇸'),
    CountryInfo(countryCode: 'TO', englishName: 'Tonga', arabicName: 'تونغا', currencyCode: 'TOP', currencyName: 'Tongan Paanga', flagEmoji: '🇹🇴'),
    CountryInfo(countryCode: 'KI', englishName: 'Kiribati', arabicName: 'كيريباتي', currencyCode: 'AUD', currencyName: 'Australian Dollar', flagEmoji: '🇰🇮'),
    CountryInfo(countryCode: 'TV', englishName: 'Tuvalu', arabicName: 'توفالو', currencyCode: 'AUD', currencyName: 'Australian Dollar', flagEmoji: '🇹🇻'),
    CountryInfo(countryCode: 'NR', englishName: 'Nauru', arabicName: 'ناورو', currencyCode: 'AUD', currencyName: 'Australian Dollar', flagEmoji: '🇳🇷'),
    CountryInfo(countryCode: 'FM', englishName: 'Micronesia', arabicName: 'ميكرونيزيا', currencyCode: 'USD', currencyName: 'US Dollar', flagEmoji: '🇫🇲'),
    CountryInfo(countryCode: 'MH', englishName: 'Marshall Islands', arabicName: 'جزر مارشال', currencyCode: 'USD', currencyName: 'US Dollar', flagEmoji: '🇲🇭'),
    CountryInfo(countryCode: 'PW', englishName: 'Palau', arabicName: 'بالاو', currencyCode: 'USD', currencyName: 'US Dollar', flagEmoji: '🇵🇼'),

    // Additional UN-recognized countries not grouped above
    CountryInfo(countryCode: 'AM', englishName: 'Armenia', arabicName: 'أرمينيا', currencyCode: 'AMD', currencyName: 'Armenian Dram', flagEmoji: '🇦🇲'),
    CountryInfo(countryCode: 'AZ', englishName: 'Azerbaijan', arabicName: 'أذربيجان', currencyCode: 'AZN', currencyName: 'Azerbaijani Manat', flagEmoji: '🇦🇿'),
    CountryInfo(countryCode: 'GE', englishName: 'Georgia', arabicName: 'جورجيا', currencyCode: 'GEL', currencyName: 'Georgian Lari', flagEmoji: '🇬🇪'),
  ];

  static final List<_IndexedCountry> _indexedCountries =
      countries.map((country) => _IndexedCountry(country)).toList(growable: false);

  /// Search countries by Arabic/English name, aliases, country code, and currency.
  static List<CountryInfo> search(String query, {int limit = 24}) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) {
      return countries.take(limit).toList(growable: false);
    }

    final startsWith = <CountryInfo>[];
    final contains = <CountryInfo>[];

    for (final indexed in _indexedCountries) {
      if (indexed.startsWith(normalized)) {
        startsWith.add(indexed.country);
      } else if (indexed.contains(normalized)) {
        contains.add(indexed.country);
      }
      if (startsWith.length + contains.length >= limit) {
        break;
      }
    }

    return <CountryInfo>[...startsWith, ...contains].take(limit).toList(growable: false);
  }

  static CountryInfo? findByCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final country in countries) {
      if (country.countryCode == normalized) {
        return country;
      }
    }
    return null;
  }

  static CountryInfo? findByName(String name) {
    final normalized = _normalize(name);
    if (normalized.isEmpty) {
      return null;
    }

    for (final indexed in _indexedCountries) {
      if (indexed.hasExact(normalized)) {
        return indexed.country;
      }
    }
    return null;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}

class _IndexedCountry {
  _IndexedCountry(this.country)
      : _tokens = _buildTokens(country),
        _prefixTokens = _buildPrefixTokens(country);

  final CountryInfo country;
  final List<String> _tokens;
  final List<String> _prefixTokens;

  static List<String> _buildTokens(CountryInfo country) {
    final tokens = <String>{
      country.englishName.toLowerCase(),
      country.arabicName.toLowerCase(),
      country.countryCode.toLowerCase(),
      country.currencyCode.toLowerCase(),
      country.currencyName.toLowerCase(),
      ...country.searchTerms.map((term) => term.toLowerCase()),
    };
    return tokens.where((token) => token.isNotEmpty).toList(growable: false);
  }

  static List<String> _buildPrefixTokens(CountryInfo country) {
    final englishWords = country.englishName.toLowerCase().split(' ');
    final arabicWords = country.arabicName.toLowerCase().split(' ');
    return <String>{
      ...englishWords,
      ...arabicWords,
      country.countryCode.toLowerCase(),
      country.currencyCode.toLowerCase(),
      ...country.searchTerms.map((term) => term.toLowerCase()),
    }.where((token) => token.isNotEmpty).toList(growable: false);
  }

  bool startsWith(String query) {
    for (final token in _prefixTokens) {
      if (token.startsWith(query)) {
        return true;
      }
    }
    return false;
  }

  bool contains(String query) {
    for (final token in _tokens) {
      if (token.contains(query)) {
        return true;
      }
    }
    return false;
  }

  bool hasExact(String query) {
    for (final token in _tokens) {
      if (token == query) {
        return true;
      }
    }
    return false;
  }
}
