-- Speaketh_Languages.lua
-- Authentic word tables sourced from Tongues addon (languages.lua) and ShathYar addon.
-- Each language uses the same [length] = { words } bucket structure.

Speaketh_Languages = {}

-- ============================================================
-- COMMON
-- ============================================================
Speaketh_Languages["Common"] = {
    blizzard = "Common", race = {"Human","Kul Tiran","Worgen"}, faction = "Alliance",
    words = {
        [1]  = {"a","e","i","o","u","y"},
        [2]  = {"lo","ne","ve","ru","an","ti","me","lu","re","se","va","ko"},
        [3]  = {"vil","bor","ras","gol","nud","far","wos","mod","ver","ash","lon","bur","hir"},
        [4]  = {"nuff","thor","ruff","odes","noth","ador","dana","vrum","veld","vohl","lars","goth","agol","uden"},
        [5]  = {"wirsh","novas","regen","gloin","tiras","barad","garde","majis","ergin","nagan","algos","eynes","borne","melka"},
        [6]  = {"ruftos","aesire","rothas","nevren","rogesh","skilde","vandar","valesh","engoth","aziris","mandos","goibon","danieb","daegil","waldir","ealdor"},
        [7]  = {"novaedi","lithtos","ewiddan","forthis","faergas","sturume","vassild","nostyec","andovis","koshhvel","mandige","kaelsig"},
        [8]  = {"thonriss","ruftvess","aldonoth","endirvis","landowar","hamerung","cynegold","methrine","lordaere"},
        [9]  = {"gloinador","veldbarad","gothalgos","udenmajis","danagarde","vandarwos","firalaine","aetwinter","eloderung","regenthor"},
        [10] = {"vastrungen","falhedring","cynewalden","dyrstigost","aelgastron","danavandar"},
        [11] = {"wershaesire","thorlithtos","forthasador","vassildador","agolandovis","bornevalesh","farlandowar"},
        [12] = {"nevrenrothas","mandosdaegil","waldirskilde","adorstaerume","golveldbarad"},
    }
}

-- ============================================================
-- ORCISH
-- ============================================================
Speaketh_Languages["Orcish"] = {
    blizzard = "Orcish", race = {"Orc","Mag'har Orc"}, faction = "Horde",
    words = {
        [1]  = {"a","n","g","o","l","k","u","r","z"},
        [2]  = {"ha","ko","no","mu","ag","ka","gi","il"},
        [3]  = {"lok","tar","kaz","ruk","kek","mog","zug","gul","nuk","aaz","kil","ogg"},
        [4]  = {"rega","nogu","tago","uruk","kagg","zaga","grom","ogar","gesh","thok","dogg","maka","maza"},
        [5]  = {"regas","nogah","kazum","magan","no'bu","golar","throm","zugas","re'ka","no'ku","ro'th"},
        [6]  = {"thrakk","revash","nakazz","moguna","no'gor","goth'a","raznos","ogerin","gezzno","thukad","makogg","aaz'no"},
        [7]  = {"lok'tar","gul'rok","kazreth","tov'osh","zil'nok","rath'is","kil'azi"},
        [8]  = {"throm'ka","osh'kava","gul'nath","kog'zela","ragath'a","zuggossh","moth'aga"},
        [9]  = {"tov'nokaz","osh'kazil","no'throma","gesh'nuka","lok'mogul","lok'balar","ruk'ka'ha"},
        [10] = {"regasnogah","kazum'nobu","throm'bola","gesh'zugas","maza'rotha","ogerin'naz"},
        [11] = {"thrakk'reva","kaz'goth'no","no'gor'goth","kil'azi'aga","zug-zug'ama","maza'thrakk"},
        [12] = {"lokando'nash","ul'gammathar","dalggo'mazah","golgonnashar","golgonmathar","throm'ka'gesh","kazum'no'gul","lok'tar'ruk"},
        [13] = {"khaz'rogg'ahn","moth'kazoroth","thok'rogg'gul","lok'mogul'rega","gesh'throm'kaz","zugas'nagaz'no","osh'kava'gular"},
    }
}

-- ============================================================
-- ZANDALI  (Troll)
-- ============================================================
Speaketh_Languages["Zandali"] = {
    blizzard = "Zandali", race = {"Troll","Zandalari Troll"}, faction = "Horde",
    words = {
        [1] = {"m","h","e","n","a","j","i","o","u"},
        [2] = {"fu","yu","is","so","ju","fi","di","ir","im","ya","mo","ka","ta","ba"},
        [3] = {"sca","tor","wha","deh","noh","dim","mek","fus","jah","kal","sha","zul","vol","jin"},
        [4] = {"duti","cyaa","iyaz","riva","yudo","skam","ting","zali","mojo","juju","bwah","tiki","haka","vood"},
        [5] = {"ackee","nehjo","difus","atuad","siame","t'ief","wassa","caang","zulja","manda","bwana","jamba","kulti"},
        [6] = {"saakes","stoosh","quashi","bwoyar","wi'mek","deh'yo","fidong","italaf","smadda","zuljan","trolol","voodoo","hakkar"},
        [7] = {"reespek","rivasuf","yahsoda","lok'dim","craaweh","godeshi","uptfeel","zandala","sen'jin","darksha"},
        [8] = {"machette","oondasta","wehnehjo","nyamanpo","whutless","zutopong","zandalah","vol'jamba"},
        [9] = {"or'manley","fus'obeah","tor'wassa","deh'quashi","zul'godshi","mek'stoosh","sha'italaf","vol'craawh"},
    }
}

-- ============================================================
-- DWARVISH
-- ============================================================
Speaketh_Languages["Dwarvish"] = {
    blizzard = "Dwarvish", race = {"Dwarf","Dark Iron Dwarf"}, faction = "Alliance",
    words = {
        [1]  = {"a","e","o","i","u","n"},
        [2]  = {"ke","lo","we","go","am","ta","ok","dw","ha","gi","ur","mo"},
        [3]  = {"ruk","red","mok","mos","gor","kha","ahz","hor","dun","dar","mug","kel","gol","rum"},
        [4]  = {"hrim","modr","rand","khaz","grum","gear","kost","loch","gosh","guma","rune","hoga","durn","helm","skol","grim"},
        [5]  = {"goten","mitta","modor","angor","skalf","thros","dagum","havar","scyld","havas","grung","boden","thane","modan"},
        [6]  = {"syddan","rugosh","bergum","haldji","drugan","robush","modoss","modgud","storma","ironfo","magnum","bronza"},
        [7]  = {"mok-kha","kaelsag","godkent","thorneb","geardum","dun-fel","havagun","ok-hoga","ahz-gor","kha-dum","mok-red","kel-gor"},
        [8]  = {"golganar","moth-tur","gefrunon","mogodune","khaz-dum","misfaran","dun-modr","ahz-grum","gor-helm","kha-rand"},
        [9]  = {"arad-khaz","ahz-dagum","khaz-rand","mund-helm","kost-guma","dun-modor","gol-skalf","hrim-modr","gor-thane"},
        [10] = {"hoga-modan","angor-magi","midd-havas","nagga-roth","kael-skalf","durn-bergum","grum-syddan","ahz-havagun"},
        [11] = {"azgol-haman","khaz-rugosh","dun-golganar","modan-thross","gor-misfaran","haldji-modor","syddan-rune"},
    }
}

-- ============================================================
-- GNOMISH
-- ============================================================
Speaketh_Languages["Gnomish"] = {
    blizzard = "Gnomish", race = {"Gnome","Mechagnome"}, faction = "Alliance",
    words = {
        [1]  = {"g","o","c","i","t"},
        [2]  = {"ti","ga","am","ok","we","lo","ke","um"},
        [3]  = {"giz","dun","gal","gar","mos","zah","fez","nid"},
        [4]  = {"grum","lock","rand","gosh","riff","kahs","cost","dani","hine","helm"},
        [5]  = {"tiras","angor","nagin","algos","thros","mitta","haven","dagem","goten","havis"},
        [6]  = {"danieb","helmok","drugan","rugosh","gizber","dumssi","waldor","mergud"},
        [7]  = {"geardum","scrutin","ferdosr","godling","bergrim","haidren","noxtyec","thorneb","costirm"},
        [8]  = {"landivar","gefrunon","aldanoth","kahzregi","kahsgear","methrine","godunmug","mikthros"},
        [9]  = {"nockhavis","naggirath","angordame","elodmodor","elodergrim"},
        [10] = {"sihnvulden","danavandar","mundgizber","dyrstagist","ahzodaugum","frendgalva","throsigear"},
        [11] = {"thrunon'gol","robuswaldir","helmokheram","kahzhaldren","haldjinagin","skalfgizgar","lockrevoshi"},
    }
}

-- ============================================================
-- DARNASSIAN  (Night Elf / Shalassian alias)
-- ============================================================
Speaketh_Languages["Darnassian"] = {
    blizzard = "Darnassian", race = {"Night Elf","Nightborne"}, faction = "Alliance",
    words = {
        [1]  = {"o","d","n","a","e","u","i"},
        [2]  = {"al","ni","su","ri","lo","do","no","da","tu","an","fa","el"},
        [3]  = {"osa","fal","ash","tur","nor","dur","tal","anu","dor","esh","ala","sha"},
        [4]  = {"dieb","shar","alah","fulo","mush","dath","anar","rini","diel","thus","aman","ande","fala","neph"},
        [5]  = {"turus","balah","shari","ishnu","terro","talah","thera","falla","adore","thero","andan","dorni","elune"},
        [6]  = {"ishura","shando","t'as'e","ethala","neph'o","do'rah","belore","manari","ashara","dorani","falash"},
        [7]  = {"alah'ni","dor'ano","aman'ni","al'shar","shan're","asto're","ishnelo","falandu","turusal"},
        [8]  = {"eraburis","d'ana'no","mandalas","dal'dieb","thoribas","shan'dor","aman'tur","thero'al","andu'nor"},
        [9]  = {"thori'dal","banthalos","shari'fal","fala'andu","talah'tur","ashethera","ishnuadah","doranotur","elunetala"},
        [10] = {"ash'therod","isera'duna","shar'adore","thero'shan","dorados'no","fandu'aman","alah'thero","andu'shari"},
        [11] = {"shari'adune","fandu'talah","t'ase'mushal","thero'dorani","ash'eraburis","isera'belore","andu'fal'osa"},
        [12] = {"t'ase'mushal","dor'ana'badu","dur'osa'dieb","fandu'mandalas","andu'shari'fal","thero'eraburis","isera'dor'ano"},
    }
}

-- Shalassian shares Darnassian words
Speaketh_Languages["Shalassian"] = {
    blizzard = "Shalassian", race = {"Nightborne"}, faction = "Horde",
    words = Speaketh_Languages["Darnassian"].words
}

-- ============================================================
-- FORSAKEN
-- ============================================================
Speaketh_Languages["Forsaken"] = {
    blizzard = "Forsaken", race = {"Undead"}, faction = "Horde",
    words = {
        [1]  = {"o","y","e","a","i","u"},
        [2]  = {"lo","va","lu","an","ti","re","ne","me","ko","ru"},
        [3]  = {"bor","bur","ash","mod","ras","wos","lon","ver","nud","far","gol"},
        [4]  = {"thor","ruff","veld","agol","vrum","dana","uden","noth","odes","lars","vohl"},
        [5]  = {"tiras","garde","borne","gloin","wirsh","ergin","eynes","algos","nagan"},
        [6]  = {"ruftos","rothas","danieb","valesh","aziris","aesire","engoth","ealdor","vandar","mandos","skilde"},
        [7]  = {"koshvel","vassild","faergas","andovis","sturume","ewiddan","nandige","kaelsig","novaedi","lithtos"},
        [8]  = {"aldonoth","endirvis","methrine","lordaere","hamerung","thorniss","ruftvess","cynegold"},
        [9]  = {"vandarwos","eloderung","danagarde","udenmajis","regenthor","gothalgos","gloinador","aetwinter","firalaine"},
        [10] = {"danavandar","falhedring","cynewalden","dyrstigost","aelgestron"},
        [11] = {"farlandowar","thorlithos","bornevalesh","forthasador","agolandovis"},
        [12] = {"golvelbarad","nevrenrothas","waldirskilde","mandosdaegil","adorstaerume"},
    }
}

-- ============================================================
-- TAURAHE
-- ============================================================
Speaketh_Languages["Taurahe"] = {
    blizzard = "Taurahe", race = {"Tauren","Highmountain Tauren"}, faction = "Horde",
    words = {
        [1]  = {"i","o","e","a","n"},
        [2]  = {"te","ta","po","tu","lo","ki","wa"},
        [3]  = {"uku","chi","owa","kee","ich","awa","alo","rah","ish"},
        [4]  = {"nahe","balo","awak","isha","mani","tawa","towa","a'ke","halo","shte"},
        [5]  = {"nechi","shush","a'hok","nokee","tanka","ti'ha","pawni","anohe","ishte","yakee"},
        [6]  = {"ichnee","sho'wa","hetawa","washte","lomani","owachi","lakota","aloaki"},
        [7]  = {"shteawa","pikialo","ishnelo","kichalo","tihikea","sechalo"},
        [8]  = {"awaihilo","akiticha","porahalo","ovaktalo","shtumani","towateke","ishnialo","owatanka"},
        [9]  = {"echeyakee","haloyakee","tawaporah","ishne'alo","tanka'kee"},
        [10] = {"ichnee'awa","shteowachi","awaka'nahe","ishamuhale","ishte'towa"},
        [11] = {"shtumanialo","aloaki'shne","awakeekielo","lakota'mani"},
    }
}

-- ============================================================
-- DRAENEI
-- ============================================================
Speaketh_Languages["Draenei"] = {
    blizzard = "Draenei", race = {"Draenei","Lightforged Draenei"}, faction = "Alliance",
    words = {
        [1]  = {"x","o","y","g","e"},
        [2]  = {"no","me","za","xi","az","ze","il","ul","ur","re","te"},
        [3]  = {"zar","lek","ruk","ril","shi","asj","daz","kar","lok","tor","maz","laz"},
        [4]  = {"aman","raka","maez","amir","zenn","rikk","alar","veni","ashj","zila"},
        [5]  = {"rakir","soran","adare","belan","modas","buras","golad","kamil","melar","refir","zekul","tiros","revos"},
        [6]  = {"mannor","arakal","thorje","tichar","kazile","mishun","rakkan","revola","karkun","archim","azgala","rakkas","rethul"},
        [7]  = {"karaman","tiriosh","danashj","toralar","zennshi","rethule","amanare","gulamir","faramos","belaros","faralos"},
        [8]  = {"sorankar","romathis","theramas","rukadare","azrathud","belankar","ashjraka","maladath","enklizar","mordanas","azgalada"},
        [9]  = {"nagasraka","melamagas","arakalada","melarorah","soranaman","teamanare","naztheros"},
        [10] = {"burasadare","amanemodas","ashjrethul","pathrebosh","zennrakkan","matheredor","kamilgolad","benthadoom","ticharamir"},
        [11] = {"ashjrakamas","mishunadare","zekulrakkas","archimtiros","mannorgulan","sorankaraman","azrathudamir"},
        [12] = {"zennshinagas","archimmannor","ashjrakkasel","burasadareka","kamilgoladze","enkilzaraman"},
    }
}

-- ============================================================
-- THALASSIAN  (Blood Elf / Void Elf / Sindassi)
-- ============================================================
Speaketh_Languages["Thalassian"] = {
    blizzard = "Thalassian", race = {"Blood Elf","Void Elf"}, faction = nil,
    words = {
        [1]  = {"o","n","d","e","a","i","u"},
        [2]  = {"an","su","ni","no","lo","ri","da","do","al"},
        [3]  = {"tal","anu","ash","nor","tur","fal","dor","ano"},
        [4]  = {"shar","rini","fulo","dath","mush","andu","anar","alah","diel","dieb"},
        [5]  = {"adore","terro","talah","bandu","balah","turus","eburi","thera","shano","shari","ishnu","fandu"},
        [6]  = {"fallah","neph'o","t'as'e","man'ar","dorini","u'phol","do'rah","ishura","shando","ethala"},
        [7]  = {"dor'ano","anoduna","shan're","mush'al","alah'ni","asto're","anu'dor","fal'ash"},
        [8]  = {"d'ana'no","dorithur","eraburis","thoribas","dal'dieb","mandalas","il'amare"},
        [9]  = {"fala'andu","neph'anis","banthalos","dune'adah","shari'fal","thori'dal","dath'anar"},
        [10] = {"isera'duna","shar'adore","dorados'no","ash'therod","thero'shan"},
        [11] = {"shari'adune","fandu'talah","dal'dieltha","fala'anshus","andu'falash","thero'ashnu","belore'shan"},
    }
}

-- ============================================================
-- GOBLIN
-- ============================================================
Speaketh_Languages["Goblin"] = {
    blizzard = "Goblin", race = {"Goblin"}, faction = "Horde",
    words = {
        [1] = {"ak","rt","ik","um","fr","bl","zz","ap","un","ek"},
        [2] = {"eet","paf","gak","erk","gip","nap","kik","bap","ikk","grk"},
        [3] = {"tiga","moof","bitz","akak","ripl","foop","keek","errk","apap","rakr"},
        [4] = {"fibit","shibl","nebit","ababl","iklik","nubop","krikl","zibit","amama","apfap"},
        [5] = {"ripdip","skoopl","bapalu","oggnog","yipyip","kaklak","ikripl","bipfiz","kiklix","nufazl"},
        [6] = {"igglepop","bakfazl","rapnukl","fizbikl","lapadap","biglkip","nibbipl","fuzlpop","gipfizy","babbada"},
        [7] = {"ibbityip","etiggara","saklpapp","ukklnukl","bendippl","ikerfafl","ikspindl","kerpoppl","hopskopl"},
        [8] = {"hapkranky","skippykik","nogglefrap","rripdipskiplip","bapfizzpop","gakernukl","frapbiggik","kiklixfoop"},
        [9] = {"napfazzyboggin","kikklpipkikkl","nibbityfuzhips","hikkitybippl","oggnoggfizzle","bapbalufrapl","ripdipnubbik","yipyipskoopl"},
    }
}

-- ============================================================
-- PANDAREN
-- ============================================================
Speaketh_Languages["Pandaren"] = {
    blizzard = "Pandaren", race = {"Pandaren"}, faction = nil,
    words = {
        [1] = {"shan","li","mei","hao","jin","ren","tao","shu","yun","kai","lan","zen"},
        [2] = {"shan li","mei hao","jin tao","ren shu","yun kai","lan zen","hao jin","shu mei","tao ren","kai lan"},
        [3] = {"shan li tao","mei hao jin","ren shu kai","yun lan zen","tao jin ren","hao mei shu","kai shan li","lan yun tao"},
        [4] = {"shan li tao ren","mei hao jin shu","yun kai lan zen","tao ren shan li","hao mei shu jin","kai lan tao ren","shu jin mei hao","lan zen yun kai"},
    }
}

-- ============================================================
-- DEMONIC  (Eredun / Draconic / Titan — shared table)
-- ============================================================
Speaketh_Languages["Demonic"] = {
    blizzard = "Demonic", race = {"Demon Hunter"}, faction = nil,
    words = {
        [1]  = {"a","e","i","o","u","y","g","x"},
        [2]  = {"il","no","az","te","ur","za","ze","re","ul","me","xi"},
        [3]  = {"tor","gul","lok","asj","kar","lek","daz","maz","ril","ruk","laz","shi","zar"},
        [4]  = {"ashj","alar","orah","amir","aman","ante","kiel","maez","maev","veni","raka","zila","zenn","parn","rikk"},
        [5]  = {"melar","ashke","rakir","tiros","modas","belan","zekul","soran","gular","enkil","adare","golad","buras","nagas","revos","refir","kamil"},
        [6]  = {"rethul","rakkan","rakkas","tichar","mannor","archim","azgala","karkun","revola","mishun","arakal","kazile","thorje"},
        [7]  = {"belaros","tiriosh","faramos","danashj","amanare","kieldaz","karaman","gulamir","toralar","rethule","zennshi"},
        [8]  = {"maladath","kirasath","romathis","theramas","azrathud","mordanas","amanalar","ashjraka","azgalada","rukadare","sorankar","enkilzar","belankar"},
        [9]  = {"naztheros","zilthuras","kanrethad","melarorah","arakalada","soranaman","nagasraka","teamanare"},
        [10] = {"matheredor","ticharamir","pathrebosh","benthadoom","enkilgular","burasadare","melarnagas","zennrakkan","ashjrethul","amanemodas","kamilgolad"},
        [11] = {"zekulrakkas","archimtiros","mannorgulan","mishunadare","ashjrakamas","enkilgulami","kanrethadash"},
        [12] = {"zennshinagas","archimmannor","ashjrakkasel","burasadareka","kamilgoladze","enkilsoranah"},
    }
}

-- Draconic shares Demonic
Speaketh_Languages["Draconic"] = {
    blizzard = "Draconic", race = {"Dracthyr"}, faction = nil,
    words = Speaketh_Languages["Demonic"].words
}

-- ============================================================
-- NERUBIAN  (also Qiraji)
-- ============================================================
Speaketh_Languages["Nerubian"] = {
    blizzard = nil, race = nil, faction = nil,
    words = {
        [1]  = {"m","a","t","c","k","s","u"},
        [2]  = {"s'k","ix","t'k","w'k","qa","h'r","ph","te","en","m'g"},
        [3]  = {"ikh","mar","has","mah","chk","mhj","rhj","ner","kah","sdh","aa't","k'st","at't","hs'p"},
        [4]  = {"mh'gh","tckh","sujt","gash","tadh","hasn","kuht","ahpt","gher","hadr","ahtj","anq'j","uahr","katc","nifn","tajh"},
        [5]  = {"hsatl","tihkh","nerub","ankan","anhqi","mersk","ahtil","tuhtl","nehhm","tutha","xstha","rhash","huskh","ankha","tchir","cthsu","khath","nedhk"},
        [6]  = {"natchk","arahtl","st'hcha","ner'zuh","anshtj","thema't","xhlatl","tutank","mahcrj","amnenn","ras'zuj","ak'schk"},
        [7]  = {"amni'gkh","zh'aqlir","gaishan","as'aith","khashab","tahattu","ahamtik","amhawnj","ner'khan","zub'amna","narjhgt","ash'rhjn"},
        [8]  = {"thsk'anqi","ashnt'khu","ahtshakh","amraa'nsh","anj'khasz","aman'ginh","chak'sckh","abrihght","thkimpsa","akh'nerig"},
        [9]  = {"amnennar","aszarh'itl","nah'ahlzir","nerub'anka","mhandarjh","ahlt'anksq","qui'xhitl"},
        [10] = {"askh'nadfir","zelk'neruzh","gahdamarah","erubtijiel","unkh'leifra","shiq'jhahnr","haf'rahtuth"},
        [11] = {"hahse'nerutl","anmhrabhskt","majhanqhji","gaht'nerdjhz","nerhtl'qansh"},
    }
}

-- ============================================================
-- NAZJA  (Naga)
-- ============================================================
Speaketh_Languages["Nazja"] = {
    blizzard = nil, race = nil, faction = nil,
    words = {
        [1]  = {"o","d","n","a","e","u","z"},
        [2]  = {"al","ni","zu","ri","lo","do","no","az","da","je","na","zi"},
        [3]  = {"osa","fal","azjh","tur","nor","dur","tal","anu","zjh","naz","sha"},
        [4]  = {"dieb","zjar","alah","fulo","muzj","dath","anar","rini","diel","thuz","aman"},
        [5]  = {"turuz","balah","zjari","izjnu","terro","talah","thera","falla"},
        [6]  = {"izjura","zjando","t'az'e","ethala","neph'o","do'rah","belore"},
        [7]  = {"alah'ni","dor'ano","aman'ni","al'zjar","zjan're","asto're","naz'tur","azj'fal"},
        [8]  = {"eraburiz","d'ana'no","mandalaz","dal'dieb","thoribaz","zjari'do","aman'azj","naz'alah"},
        [9]  = {"thori'dal","banthaloz","zjari'fal","fala'andu","talah'tur","naz'ethala","azj'do'rah","diel'zjari"},
        [10] = {"azj'therod","izera'duna","zjar'adore","thero'shan","doradoz'no","naz'izjura","fala'zjando"},
        [11] = {"zjari'adune","fandu'talah","t'ase'muzjal","thero'dorani","naz'eraburiz","izera'belore","azj'aman'ni"},
        [12] = {"t'ase'muzjal","dor'ana'badu","dur'oza'dieb","fandu'zjari'al","naz'mandalaz","thero'azj'osa"},
    }
}

-- ============================================================
-- VULPERA
-- ============================================================
Speaketh_Languages["Vulpera"] = {
    blizzard = nil, race = {"Vulpera"}, faction = "Horde",
    useRandom = true,
    words = {
        [1]  = {"y","i","o","a","u","e"},
        [2]  = {"ik","da","au","uk","aw","yi","pa","wa","ak","ho","ao","wo","po"},
        [3]  = {"gav","hau","woo","yap","arf","wan","bow","vuf","haf","pow","bau","yip","vuu","gua"},
        [4]  = {"guau","keff","lall","ahee","woef","ouah","blaf","yaap","yiip","youw","joff","ghav","meon","gheu","hyto","wooo","yiuw","wauw","vuuf","waou","ring"},
        [5]  = {"lally","hatti","wauwn","youwn","ouahn","yipyi","yiuwn","meong","waouh","wanwa","woooo","bauba","hittu","caica","tchof","hytou","gedin","hauha"},
        [6]  = {"yipyip","tchoff","geding","baubau","caicai","wanwan","guaugu","hauhau","hattii","frakak","wooowo","aheeah"},
        [7]  = {"vuufwuf","joffwau","frakaka","aheeaha","wooowoo","guaugua","wuffwoe","blafbla","gheughe"},
        [8]  = {"aheeowow","blafblaf","ghavyouw","wuffwoef","woefyouw","vuufwuff","guauguau","gheugheu"},
        [9]  = {"ghavyouwn","vuufhatti","aheeowown","joffwauwn","woefyouwn","keffgedin","blafhauha"},
        [10] = {"keffgeding","vuufhattii","blafhauhau","woofhauhau"},
    }
}

-- ============================================================
-- VRYKUL
-- ============================================================
Speaketh_Languages["Vrykul"] = {
    blizzard = nil, race = nil, faction = nil,
    words = {
        [1]  = {"v","í","o","a","ð","e","u","i","á","ý"},
        [2]  = {"il","ir","lo","hé","úl","ek","af","ól","ðr","yr","al","ís"},
        [3]  = {"dal","fén","hil","yul","sal","jor","kel","þor","rig","var","dís","arn"},
        [4]  = {"iðva","vahl","aero","wilr","uslo","þorn","galr","heil","vatn","oðin","rígr","skjá"},
        [5]  = {"thaim","opkam","vulak","sralr","þuhar","galdr","heilr","ulfar","skjol","vísir","norðr","jotun"},
        [6]  = {"tíbeir","eomhið","kalroh","invarh","oltrar","galdra","þorinn","skjald","hrafnr","valkyr","fenris","heljar"},
        [7]  = {"nafiskr","ilvarun","oskarul","álðtaul","galdrik","þornulf","hrafnar","valkyrn","fenrisr","heljarn","jormunn","skjoldr"},
        [8]  = {"vulantru","nirantyr","wassholt","lokrantr","yvoltrak","þorinnar","galdrikr","hrafnarn","valkyrnr","skjaldur"},
        [9]  = {"falrentir","ilrontuhl","tælvessin","hraulvast","vohlmanet","þornulfar","galdrikrn","hrafnarnr","valkyrnar","skjalduhr"},
        [10] = {"ektalunost","wraltruhln","æhlcarntil","yviltratos","fehltulohn","þorinnarsk","galdrikarn","hrafnarnar","valkyrnjor","fenrishelj"},
        [11] = {"ðégrentuhln","ðolíáhvuhln","aunthreltis","vrauhlektil","etvraluhtlo","þornulfarsk","galdrikarnn","valkyrnjohr","fenrisheljr","hrafnarnahr"},
        [12] = {"hrothulvahkt","ðrevuhlorkan","iltarulsolhn","eklanvuhlohr","fahlánðtarul","þorinnarskjl","galdrikarnvr","valkyrnjohrt","fenrisheljar","hrafnarnahrt"},
    }
}

-- ============================================================
-- GILNEAN  (Worgen — Cockney rhyming slang, sourced from Tongues addon)
-- Uses a substitute + ignore system instead of pure hashing.
-- ============================================================
Speaketh_Languages["Gilnean"] = {
    blizzard = nil, race = {"Worgen"}, faction = "Alliance",
    useGilneanCodeSpeak = true,
    substitute = {
        -- User-requested keyword pass-throughs
        ["hello"]       = "'ello",
        ["hi"]          = "oi",
        ["hiya"]        = "'eya",
        ["isn't"]       = "ain't",
        ["talk"]        = "gab",
        ["talking"]     = "gabbin'",
        ["trash"]       = "rubbish",
        -- Other Gilnean flavor substitutions
        ["hey"]         = "oi",
        ["what"]        = "wot",
        ["some"]        = "sum",
        ["something"]   = "sumthing",
        ["somethings"]  = "sumthings",
        ["something's"] = "sumthing's",
        ["do you"]      = "ya'",
        ["you do"]      = "ya'",
        ["whatever"]    = "wotever",
        ["you"]         = "ya'",
        ["your"]        = "yer",
        ["was"]         = "wus",
        ["you'd"]       = "yah'd",
        ["you had"]     = "yah'd",
        ["never"]       = "niver",
        ["not"]         = "no'",
        ["where"]       = "wer",
    },
    ignore = {
        ["yes"]=true, ["no"]=true, ["a"]=true, ["i"]=true,
        ["i am"]=true, ["i'm"]=true, ["we"]=true, ["we are"]=true,
        ["we're"]=true, ["going"]=true, ["go"]=true, ["for"]=true,
        ["you're"]=true, ["you are"]=true,
        ["me"]=true, ["my"]=true, ["mine"]=true,
    },
    words = {
        [1] = {"o","a","e","i","u","eh"},
        [2] = {"oy","oi","aw","ay","ai","gi","blimey","gob"},
        [3] = {"beg","peepers","crust","skein","barmy","lamps","pot","teapot","toff","titfer","mince","plates"},
        [4] = {"tack","daft","goat","airs","bottle","ticking","babbling","lemon","bread","raft","rats","sighs","pearl","calf","lids","slip","berk","biters"},
        [5] = {"hopper","stutter","tiddly","plant","trunk","scribes","graces","brook","squeezer","honey","sunny","thorn","howl"},
    }
}

-- ============================================================
-- SHATH'YAR  (Old God — authentic SStrHash word tables from ShathYar addon)
-- ============================================================
Speaketh_Languages["Shath'Yar"] = {
    blizzard = nil, race = nil, faction = nil,
    -- This language uses the SStrHash algorithm instead of the djb2 hash.
    -- Flag so Speaketh_Translate knows to use the correct hash path.
    useShathYarHash = true,
    words = {
        [1]  = {"i","y","g","x","o","a"},
        [2]  = {"ag","ez","ga","ky","ma","ni","og","za","zz"},
        [3]  = {"gag","hoq","lal","maq","nuq","oou","qam","shn","vaz","vra","yrr","zuq"},
        [4]  = {"agth","amun","arwi","fssh","ifis","kyth","nuul","ongg","puul","qwaz","qwor","ryiu","shfk","thoq","uull","vwah","vwyq","w'oq","wgah","ywaq","zaix","zzof"},
        [5]  = {"ag'rr","agthu","ak'uq","anagg","bo'al","fhssh","h'iwn","hnakf","huqth","iilth","iiyoq","lwhuk","on'ma","plahf","shkul","shuul","thyzz","uulwi","vorzz","w'ssh","yyqzz"},
        [6]  = {"ag'xig","al'tha","an'qov","an'zig","bormaz","c'toth","far'al","h'thon","halahs","iggksh","ka'kar","kaaxth","marwol","n'zoth","qualar","qvsakf","shn'ma","sk'tek","skshgn","ssaggh","tallol","tulall","uhnish","uovssh","vormos","yawifk","yoq'al","yu'gaz"},
        [7]  = {"an'shel","awtgssh","guu'lal","guulphg","iiqaath","kssh'ga","mh'naus","n'lyeth","ph'magg","qornaus","shandai","shg'cul","shg'fhn","sk'magg","sk'yahf","uul'gwa","uulg'ma","vwahuhn","woth'gl","yeh'glu","yyg'far","zyqtahg"},
        [8]  = {"awtgsshu","erh'ongg","gul'kafh","halsheth","log'loth","mar'kowa","muoq'vsh","phquathi","qi'plahf","qi'uothk","sk'shuul","sk'uuyat","ta'thall","thoth'al","uhn'agth","ye'tarin","yoh'ghyl","zuq'nish"},
        [9]  = {"ag'thyzak","ga'halahs","lyrr'keth","par'okoth","phgwa'cul","pwhn'guul","ree'thael","shath'yar","shgla'yos","shuul'wah","sshoq'meg"},
        [10] = {"ak'agthshi","shg'ullwaq","sk'woth'gl","uul'ga'hoq","ywaq'ma'ni","vorzz'kyth","zuq'ahn'qov","thyzz'nuul"},
        [11] = {"ghawl'fwata","naggwa'fssh","yeq'kafhgyl","sshoq'wgahni","shg'cul'agth","zuq'nish'gag","uulwi'shkul"},
    }
}

-- Shath'Yar hash constants (from ShathYar.lua — SStrHash algorithm)
Speaketh_SStrHash_constants = {
    0x486e26ee, 0xdcaa16b3, 0xe1918eef, 0x202dafdb, 0x341c7dc7, 0x1c365303,
    0x40ef2d37, 0x65fd5e49, 0xd6057177, 0x904ece93, 0x1c38024f, 0x98fd323b,
    0xe3061ae7, 0xa39b0fa1, 0x9797f25f, 0xe4444563, 0xdcaa16b3, 0x486e26ee,
    0x202dafdb, 0xe1918eef, 0x1c365303, 0x341c7dc7, 0x65fd5e49, 0x40ef2d37,
    0x904ece93, 0xd6057177, 0x98fd323b, 0x1c38024f, 0xa39b0fa1, 0xe3061ae7,
    0xe4444563, 0x9797f25f, 0x8dc1b898, 0xcd2ec20c, 0x799a306d, 0x31759633,
    0x2e6e9627, 0x8c206385, 0x73922c66, 0x79237d99, 0x28628824, 0x8728628d,
    0x25887795, 0x8f1f7e96, 0x389c0d60, 0x296e3281, 0x61636542, 0x6f4893ca,
}

function Speaketh_SStrHash(word)
    local seed1 = 0x7FED7FED
    local seed2 = 0xEEEEEEEE
    word = string.upper(word)
    for i = 1, word:len() do
        local ch = word:byte(i)
        seed1 = bit.bxor(seed1 + seed2,
            (Speaketh_SStrHash_constants[bit.rshift(ch, 4) + 1] -
             Speaketh_SStrHash_constants[bit.band(ch, 0xf) + 1]))
        seed2 = bit.lshift(seed2, 5) + seed2 + ch + seed1 + 3
    end
    return seed1
end

-- ============================================================
-- Lookup helpers
-- ============================================================
Speaketh_BlizzardToKey = {}
for key, data in pairs(Speaketh_Languages) do
    if data.blizzard then
        Speaketh_BlizzardToKey[data.blizzard] = key
    end
end

Speaketh_LanguageOrder = {
    "Common","Orcish","Darnassian","Thalassian","Taurahe","Dwarvish",
    "Forsaken","Gnomish","Zandali","Draenei","Goblin","Pandaren",
    "Shalassian","Draconic","Demonic","Nerubian","Nazja","Vulpera","Vrykul",
    "Gilnean","Shath'Yar",
}

-- ============================================================
-- Custom language API
-- ============================================================
-- Builds a word-bucket table from a flat list of user-supplied words.
-- Words are sorted into buckets by character length, then the translation
-- engine picks from those buckets by hash, exactly like built-in languages.
local function BuildWordBuckets(wordList)
    local buckets = {}
    for _, w in ipairs(wordList) do
        local len = math.max(1, math.min(#w, 12))
        if not buckets[len] then buckets[len] = {} end
        table.insert(buckets[len], w:lower())
    end
    -- Fill any missing buckets by borrowing from the nearest available
    local maxLen = 0
    for k in pairs(buckets) do if k > maxLen then maxLen = k end end
    for i = 1, maxLen do
        if not buckets[i] then
            local fallback = nil
            for j = i - 1, 1, -1 do if buckets[j] then fallback = buckets[j]; break end end
            if not fallback then
                for j = i + 1, maxLen do if buckets[j] then fallback = buckets[j]; break end end
            end
            if fallback then buckets[i] = fallback end
        end
    end
    return buckets
end

-- Register a custom language into the live tables.
-- Called both when the user creates one and on PLAYER_LOGIN to restore saved ones.
-- If the language already exists (re-registration for editing), update it in place.
function Speaketh_RegisterCustomLanguage(key, name, wordList)
    Speaketh_Languages[key] = {
        name      = name,
        isCustom  = true,
        words     = BuildWordBuckets(wordList),
    }
    -- Append to order list if not already present
    local found = false
    for _, k in ipairs(Speaketh_LanguageOrder) do
        if k == key then found = true; break end
    end
    if not found then
        table.insert(Speaketh_LanguageOrder, key)
    end
end

-- Remove a custom language from the live tables.
function Speaketh_UnregisterCustomLanguage(key)
    Speaketh_Languages[key] = nil
    for i, k in ipairs(Speaketh_LanguageOrder) do
        if k == key then table.remove(Speaketh_LanguageOrder, i); break end
    end
end
