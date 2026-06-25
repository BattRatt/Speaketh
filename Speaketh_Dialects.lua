-- Speaketh_Dialects.lua
-- Dialect / accent system.  Every dialect uses a 0-3 intensity slider.
-- Level 0 = off, 1 = light, 2 = moderate, 3 = full.
-- Substitutions are tiered: each sub has a minimum level to activate.

Speaketh_Dialects = {}

-- ============================================================
-- Registry
-- ============================================================
local DIALECTS = {}
local DIALECT_ORDER = {}

local function RegisterDialect(key, data)
    DIALECTS[key] = data
    table.insert(DIALECT_ORDER, key)
end

-- ============================================================
-- Helpers
-- ============================================================
local function MatchCase(original, replacement)
    if original == original:upper() then
        return replacement:upper()
    elseif original:sub(1,1) == original:sub(1,1):upper() then
        return replacement:sub(1,1):upper() .. replacement:sub(2)
    else
        return replacement:lower()
    end
end

-- Apply word-boundary-aware substitutions.
-- Each entry in subs is {phrase, replacement, minLevel}.
-- Only entries with minLevel <= current level fire.
local function ApplySubstitutes(text, subs, level)
    if not subs then return text end

    -- Filter to active subs and sort longest-first
    local active = {}
    for _, entry in ipairs(subs) do
        if level >= entry[3] then
            table.insert(active, entry)
        end
    end
    table.sort(active, function(a, b) return #a[1] > #b[1] end)

    for _, entry in ipairs(active) do
        local lower = text:lower()
        local searchLower = entry[1]:lower()
        local out = {}
        local pos = 1
        while pos <= #text do
            local s, e = lower:find(searchLower, pos, true)
            if s then
                local before = (s == 1) or not text:sub(s-1, s-1):match("[%a']")
                local after  = (e == #text) or not text:sub(e+1, e+1):match("[%a']")
                if before and after then
                    table.insert(out, text:sub(pos, s - 1))
                    table.insert(out, MatchCase(text:sub(s, e), entry[2]))
                    pos = e + 1
                else
                    table.insert(out, text:sub(pos, s))
                    pos = s + 1
                end
            else
                table.insert(out, text:sub(pos))
                break
            end
        end
        text = table.concat(out)
    end
    return text
end

-- ============================================================
-- Contextual rule engine (built-in dialects only)
-- ------------------------------------------------------------
-- The plain {from,to} substitutions above are flat: a rule fires
-- every time its word appears, with no regard for grammar. That is
-- fine for flavour words ("gold"->"plunder") but produces clumsy
-- output for grammatical words ("is"->"be" firing in every clause,
-- "my"->"mine" giving "mine sword", openers like "ahoy" landing in
-- the middle of a sentence, etc).
--
-- This engine adds a SECOND, code-only layer that runs grammar-aware
-- transforms. These rules are NOT stored in saved variables, so:
--   * they never appear in (or interfere with) the rule editor,
--   * they never touch custom dialects or user-added words,
--   * they apply to every character immediately, no re-seed needed.
--
-- Each contextual rule is a function(text, level) -> text. They are
-- tokeniser-friendly: we work on a word list so we can see a word's
-- neighbours and its position in the sentence.
-- ============================================================

-- Split text into an alternating list of word / non-word (gap) chunks,
-- so we can rebuild the string verbatim after editing individual words.
-- Returns: tokens = { {w=word, g=trailingGap}, ... }, leadingGap
local function Tokenize(text)
    local tokens = {}
    local pos = 1
    local leading = ""
    -- capture any leading non-word characters
    local ws, we = text:find("[%a']+", pos)
    if ws and ws > pos then
        leading = text:sub(pos, ws - 1)
    elseif not ws then
        return {}, text
    end
    pos = ws
    while pos <= #text do
        local s, e = text:find("[%a']+", pos)
        if not s then break end
        local word = text:sub(s, e)
        -- gap that follows this word, up to the next word (or end)
        local ns = text:find("[%a']+", e + 1)
        local gap
        if ns then
            gap = text:sub(e + 1, ns - 1)
        else
            gap = text:sub(e + 1)
        end
        table.insert(tokens, { w = word, g = gap })
        pos = e + 1 + #gap
    end
    return tokens, leading
end

local function Detokenize(tokens, leading)
    local out = { leading or "" }
    for _, t in ipairs(tokens) do
        -- Skip tokens a rule emptied (e.g. de-dup removals); don't emit
        -- their (already-cleared) gap either.
        if t.w ~= "" then
            out[#out + 1] = t.w
            out[#out + 1] = t.g or ""
        end
    end
    local s = table.concat(out)
    -- Normalise spacing left behind by removed tokens: collapse runs of
    -- spaces, tidy " ," -> ",", and trim a trailing space. Newlines and
    -- other whitespace are preserved by only squeezing plain spaces.
    s = s:gsub("  +", " ")
    s = s:gsub(" +([%.%?!,;:])", "%1")
    s = s:gsub("%s+$", "")
    return s
end

-- Case-copy: make `repl` follow the capitalisation pattern of `orig`.
local function CopyCase(orig, repl)
    if orig == orig:upper() and orig:match("%u%u") then
        return repl:upper()
    elseif orig:sub(1,1):match("%u") then
        return repl:sub(1,1):upper() .. repl:sub(2)
    else
        return repl:lower()
    end
end

local VOWEL_START = "^[aeiouAEIOU]"

-- True if the word (already lowercased core) ends a sentence / clause,
-- judged by the trailing gap punctuation.
local function EndsClause(gap)
    return gap and gap:match("[%.%?!,;:]") ~= nil
end

-- Strip a word down to its alphabetic core (drop a leading apostrophe etc.)
local function Core(word)
    return (word:gsub("^[^%a]+", ""):gsub("[^%a']+$", ""))
end

-- A contextual rule has:
--   match(prevCore, curCore, nextCore, isFirst, isLast, prevGap, curGap)
--      -> replacement string (already cased) or nil to leave unchanged.
-- We pass lowercased cores for matching and re-apply case from the
-- original token.
local function ApplyContextRules(text, rules, level)
    if not rules or #rules == 0 then return text end
    local tokens, leading = Tokenize(text)
    if #tokens == 0 then return text end

    -- Pre-extract lowercase cores
    local cores = {}
    for i, t in ipairs(tokens) do
        cores[i] = Core(t.w):lower()
    end

    for _, rule in ipairs(rules) do
        if level >= (rule.minLevel or 1) then
            -- Refresh cores from current token state BEFORE this pass. A
            -- previous rule may have mutated a NEIGHBOUR token (e.g. blanking
            -- the "to" in "going to" -> "gonna", the "at" after "lookit", or
            -- the pronoun after "whaddya"). Without this refresh, a later rule
            -- would still see the stale core (e.g. "to") for a now-empty token
            -- and "resurrect" it (the "gonnata" / "gonna tahurt" bug).
            for k, t in ipairs(tokens) do
                cores[k] = Core(t.w):lower()
            end
            for i, t in ipairs(tokens) do
                -- A token blanked by an earlier rule has no core; skip it so
                -- we never match or rewrite an emptied slot.
                if cores[i] ~= "" then
                    local prev = cores[i-1]
                    local cur  = cores[i]
                    local nxt  = cores[i+1]
                    local prevGap = (i > 1) and tokens[i-1].g or ""
                    local repl = rule.fn(prev, cur, nxt, i == 1, i == #tokens,
                                         prevGap, t.g, tokens, i)
                    if repl ~= nil then
                        -- A context rule replaces the whole word. We keep only a
                        -- leading/trailing NON-apostrophe symbol (rare, since most
                        -- punctuation lives in the gap); apostrophes are treated as
                        -- part of the word/contraction and are NOT re-appended, so
                        -- "goin'" -> "gonna" never becomes "gonna'".
                        local pre  = t.w:match("^[^%a']*") or ""
                        local post = t.w:match("[^%a']*$") or ""
                        local body = t.w:sub(#pre + 1, #t.w - #post)
                        tokens[i].w = pre .. CopyCase(body, repl) .. post
                        cores[i] = Core(tokens[i].w):lower()
                    end
                end
            end
        end
    end

    return Detokenize(tokens, leading)
end

-- ------------------------------------------------------------
-- Article agreement (a / an).
-- Any swap that changes the word AFTER an article can break "a/an"
-- agreement: "an old man" -> "an barnacled scallywag" (wrong: should be
-- "a barnacled..."), or "a apple" if a vowel word appears. This pass
-- runs LAST, after every other transform, and rewrites a/an to match the
-- sound of whatever word now follows. It is built-in only and never
-- touches custom dialects.
--
-- We use a simple, robust heuristic: "an" before a vowel sound, "a"
-- otherwise. We special-case a few common silent-h words ("hour",
-- "honest", "honor") that take "an", and a few vowel-letter words that
-- actually take "a" ("a unicorn", "a one"). Not perfect English, but it
-- removes the jarring "an barnacled" / "a apple" cases.
-- ------------------------------------------------------------
local AN_EXCEPTIONS = {  -- start with a vowel LETTER but take "a"
    unicorn = true, unique = true, united = true, universe = true,
    university = true, european = true, ["one"] = true, once = true,
    use = true, used = true, useful = true, user = true, ewe = true,
}
local A_EXCEPTIONS = {   -- start with a consonant LETTER but take "an"
    hour = true, honest = true, honestly = true, honor = true,
    honour = true, honorable = true, heir = true, herb = true,
}

local function FixArticles(text)
    -- token-stream rewrite, preserving spacing/case
    local tokens, leading = Tokenize(text)
    if #tokens == 0 then return text end
    for i = 1, #tokens - 1 do
        local cur = Core(tokens[i].w):lower()
        if cur == "a" or cur == "an" then
            local nextCore = Core(tokens[i+1].w):lower()
            if nextCore ~= "" then
                local first = nextCore:sub(1,1)
                local wantsAn
                if A_EXCEPTIONS[nextCore] then
                    wantsAn = true
                elseif AN_EXCEPTIONS[nextCore] then
                    wantsAn = false
                else
                    wantsAn = first:match("[aeiou]") ~= nil
                end
                local target = wantsAn and "an" or "a"
                if cur ~= target then
                    -- preserve original capitalisation of the article
                    local orig = tokens[i].w
                    local pre  = orig:match("^[^%a']*") or ""
                    local post = orig:match("[^%a']*$") or ""
                    local body = orig:sub(#pre + 1, #orig - #post)
                    tokens[i].w = pre .. CopyCase(body, target) .. post
                end
            end
        end
    end
    -- Detokenize WITHOUT the whitespace-squeeze used elsewhere is fine;
    -- reuse Detokenize for consistency (it only trims trailing space).
    return Detokenize(tokens, leading)
end

-- Helper: standard set of "to be" forms used by several dialects.
local BE_FORMS = {
    is = true, are = true, am = true, was = true, were = true,
}

-- Determiner / noun-phrase-opener set. After "going to", if one of these
-- (or a dialect-swapped equivalent like "da") follows, then "to" is the
-- PREPOSITION "to" introducing a destination ("going to the market"), not
-- the infinitive marker ("going to fight"). In the prepositional case
-- "gonna" is wrong ("gonna the market"), so the collapse must be skipped.
local NP_OPENERS = {
    a = true, an = true, the = true, da = true, tha = true,
    this = true, that = true, these = true, those = true,
    dis = true, dat = true, dese = true, dose = true,
    my = true, mine = true, your = true, yer = true, ya = true,
    ["ya'"] = true, his = true, her = true, our = true, their = true,
    dere = true, its = true, me = true, some = true, any = true,
    every = true, no = true, ["another"] = true, each = true,
}

-- True when "going to <next2>" is prepositional (destination) rather than
-- the infinitive "going to <verb>". Conservative: only treats a clear
-- determiner/possessive opener as prepositional, so genuine infinitives
-- ("gonna win", "gonna leave") still collapse.
local function GoingToIsPrepositional(next2)
    return next2 ~= nil and NP_OPENERS[next2] == true
end

-- ------------------------------------------------------------
-- Built-in contextual rule sets, per dialect.
-- These complement (run AFTER) the flat substitutions, fixing the
-- specific grammar cases that flat swaps get wrong.
-- ------------------------------------------------------------
local CONTEXT_RULES = {}

-- ===== PIRATE =====
-- Flat rules already do my->me, you->ye, gold->plunder, etc.
-- The flat list intentionally OMITS is/are->be now; we handle copulas
-- here so they only collapse where it actually sounds piratey, and we
-- add sentence-opener logic for greetings.
CONTEXT_RULES.Pirate = {
    -- "is"/"are" -> "be" only when followed by an article/possessive or
    -- a determiner-like word, which is where pirate-speak "she be a fine
    -- ship" reads naturally. Avoids mangling "this is" chains.
    {
        minLevel = 2,
        fn = function(prev, cur, nxt)
            if (cur == "is" or cur == "are") and nxt then
                if nxt == "a" or nxt == "an" or nxt == "the"
                   or nxt == "me" or nxt == "yer" or nxt == "ye"
                   or nxt == "my" or nxt == "your" then
                    return "be"
                end
            end
            return nil
        end,
    },
    -- "am" -> "be" ("I be Captain") at full tilt only.
    {
        minLevel = 3,
        fn = function(prev, cur)
            if cur == "am" and prev == "i" then return "be" end
            return nil
        end,
    },
    -- Sentence-opening greeting: a lone "hello/hi/hey" at the very start
    -- becomes "Ahoy"; mid-sentence ones are left to the flat rule so we
    -- don't double up.
    {
        minLevel = 1,
        fn = function(prev, cur, nxt, isFirst)
            if isFirst and (cur == "hello" or cur == "hi" or cur == "hey") then
                return "ahoy"
            end
            return nil
        end,
    },
    -- "look" -> "spy", consuming a following "at" so "look at the ship"
    -- becomes "spy the ship" (not "spy at the ship"). "look for/around/out"
    -- keep "look" since "spy for" reads oddly.
    --
    -- This rule is also DEFENSIVE: a stale flat rule "look"->"spy" in old
    -- saved data can fire before the context engine, so the word arriving
    -- here may already be "spy". We therefore match BOTH "look" and "spy"
    -- and re-derive the correct, fully-flowing result:
    --   * "spy at ye"  (from flat look->spy + you->ye) -> "spy ye"
    --   * "spy for ..." / "spy around" (reads oddly)   -> revert to "look"
    -- so the output is identical whether or not the prune ran.
    {
        minLevel = 2,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap, toks, i)
            if cur ~= "look" and cur ~= "spy" then return nil end
            -- "look at X" / "spy at X" -> "spy X" (drop the stranded "at")
            if nxt == "at" then
                toks[i+1].w = ""
                toks[i+1].g = ""
                return "spy"
            end
            -- Particles where "spy" reads wrong; keep/restore plain "look".
            local keep = { ["for"]=true, around=true, out=true, into=true,
                           after=true, up=true, upon=true, over=true }
            if nxt and keep[nxt] then
                -- If a stale flat rule already turned it into "spy", undo it.
                if cur == "spy" then return "look" end
                return nil
            end
            -- Bare/standalone or transitive use: "spy" is correct.
            return "spy"
        end,
    },
    -- "stop" -> "belay" only when intransitive/imperative ("belay!" / "stop
    -- running" -> "belay runnin'"). With an object ("stop me from...") keep
    -- "stop" so we avoid "belay me from winning".
    --
    -- DEFENSIVE: a stale flat rule "stop"->"belay" can fire first, so the
    -- word may already be "belay" by the time we see it. We match BOTH and
    -- re-decide from grammar: a transitive "belay me"/"belay that" is wrong
    -- and gets reverted to "stop", while a true intransitive/imperative use
    -- keeps "belay". Output is identical whether or not the prune ran.
    {
        minLevel = 1,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap)
            if cur ~= "stop" and cur ~= "belay" then return nil end
            -- Intransitive / imperative: end of clause, or before a gerund.
            local intransitive = isLast or EndsClause(curGap)
                                 or (nxt ~= nil and nxt:match("ing$") ~= nil)
            if intransitive then return "belay" end
            -- Transitive (an object follows): "belay" is wrong here. If a
            -- stale flat rule produced "belay", restore "stop".
            if cur == "belay" then return "stop" end
            return nil
        end,
    },
}

-- ===== TROLL =====
-- Flat rules do da/dis/dat, ya, tink, etc. The big offender is the
-- universal is/are/am/was/were -> "be" at level 3, which flattens tense
-- entirely ("I be tired yesterday"). We make it tense-aware and
-- subject-aware so it sounds like Darkspear cadence, not word soup.
CONTEXT_RULES.Troll = {
    -- Present-tense copula -> "be" (ya be, dey be, it be). Past tense
    -- (was/were) is left mostly intact for readability except at full.
    {
        minLevel = 2,
        fn = function(prev, cur)
            if cur == "is" or cur == "are" or cur == "am" then
                return "be"
            end
            return nil
        end,
    },
    -- At full intensity, past copula collapses too, but only mid-clause
    -- (keeps "Was it ya?" style openers readable).
    {
        minLevel = 3,
        fn = function(prev, cur, nxt, isFirst)
            if (cur == "was" or cur == "were") and not isFirst then
                return "be"
            end
            return nil
        end,
    },
    -- "to be going" cadence: "going to" -> "gonna" handled as a pair so
    -- it flows ("Ya gonna fight") instead of "goin' to". But ONLY when the
    -- infinitive "to <verb>" follows. Before a destination noun phrase
    -- ("going to da market") "to" is the preposition and "gonna da market"
    -- is wrong, so we leave "going"/"goin'" + "to" intact in that case.
    {
        minLevel = 2,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap, toks, i)
            if (cur == "going" or cur == "goin'" or cur == "goin")
               and nxt == "to" and not EndsClause(curGap) then
                -- Peek at the word AFTER "to". If it opens a noun phrase
                -- (article/possessive/etc), this is "going to <place>" and
                -- must not collapse to "gonna".
                local next2 = toks[i+2] and Core(toks[i+2].w):lower() or nil
                if GoingToIsPrepositional(next2) then
                    return nil
                end
                -- rewrite this token to "gonna" and blank the next "to"
                toks[i+1].w = ""
                toks[i].g = (toks[i].g or "")  -- keep gap
                -- collapse the doubled space left by removing "to"
                if toks[i+1].g and toks[i].g == " " then
                    toks[i].g = toks[i+1].g
                    toks[i+1].g = ""
                end
                return "gonna"
            end
            return nil
        end,
    },
    -- "mon" de-spam. Several flat rules independently produce "mon"
    -- (greetings hi/hey/hello -> "ey mon", yes -> "ya mon", and the nouns
    -- friend/man/dude -> "mon"). The genuinely broken case is when two land
    -- ADJACENT, e.g. "Hello friend" -> "ey mon mon". We collapse only an
    -- immediately-adjacent duplicate, so meaningful later nouns survive:
    --   "Hello friend"          -> "Ey mon"          (adjacent: collapsed)
    --   "The man is my friend"  -> "Da mon be me mon" (not adjacent: kept)
    -- Built-in only; custom dialects/words are untouched.
    {
        minLevel = 1,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap, toks, i)
            if cur ~= "mon" then return nil end
            if prev ~= "mon" then return nil end
            -- Only collapse when the two "mon"s are separated by simple
            -- whitespace (no comma/clause break between them).
            local gapBetween = toks[i-1].g or ""
            if gapBetween:match("[%.%?!,;:]") then return nil end
            -- Drop this (the second) "mon"; fold its gap onto the first.
            toks[i-1].g = toks[i].g or ""
            toks[i].w = ""
            toks[i].g = ""
            return nil
        end,
    },
}

-- ===== GILNEAN =====
-- Flat rules do th->f (fink, fing), ya', dropped-g, da/dat at L3.
-- Problems: "the"->"da" everywhere at L3 is heavy; and h-dropping is
-- the signature Cockney feature but the flat list only h-drops a few
-- fixed words. We add general, light h-dropping on common words and
-- keep "the"->"da" only before consonants (so "the apple" stays "the").
CONTEXT_RULES.Gilnean = {
    -- "the" -> "da" only before a consonant-initial word, and only at
    -- full intensity. Before a vowel it stays "the" (sounds wrong as
    -- "da apple").
    {
        minLevel = 3,
        fn = function(prev, cur, nxt)
            if cur == "the" and nxt and not nxt:match(VOWEL_START) then
                return "da"
            end
            return nil
        end,
    },
    -- "and" -> "an'" connective, light and natural at L2+.
    {
        minLevel = 2,
        fn = function(prev, cur)
            if cur == "and" then return "an'" end
            return nil
        end,
    },
    -- "of" -> "o'" at L2+ ("pint o' ale").
    {
        minLevel = 2,
        fn = function(prev, cur)
            if cur == "of" then return "o'" end
            return nil
        end,
    },
    -- "to" -> "ta" mid-sentence at full ("goin' ta market").
    {
        minLevel = 3,
        fn = function(prev, cur, nxt, isFirst)
            if cur == "to" and not isFirst then return "ta" end
            return nil
        end,
    },
}

-- ===== LORDAERON (formal / archaic) =====
-- This dialect benefits most from grammar awareness — archaic English
-- has real agreement rules the flat list can't express.
CONTEXT_RULES.Lordaeron = {
    -- "my" -> "mine" ONLY before a vowel or 'h' ("mine honour", "mine
    -- eyes"); otherwise stays "my" ("my sword"). The flat list used a
    -- blanket my->mine which produced "mine sword". We DO NOT put my->mine
    -- in the flat list anymore; this rule owns it.
    --
    -- DEFENSIVE: a stale blanket "my"->"mine" flat rule in old saved data
    -- would give "mine sword". Match "mine" too and revert it to "my"
    -- before a consonant, so output is correct regardless of the prune.
    {
        minLevel = 2,
        fn = function(prev, cur, nxt)
            if (cur == "my" or cur == "mine") and nxt then
                local beforeVowelOrH = nxt:match(VOWEL_START)
                                       or nxt:sub(1,1):lower() == "h"
                if beforeVowelOrH then return "mine" end
                -- consonant follows: possessive "my"; undo any stale "mine".
                if cur == "mine" then return "my" end
            end
            return nil
        end,
    },
    -- "thee" vs "thou": "you" as a subject -> "thou"; as an object -> "thee".
    -- Subject when: it starts a clause, OR a verb follows it (thou knowest),
    -- OR an auxiliary/copula immediately precedes it in a question
    -- ("how are you" / "do you" -> "...thou"). Otherwise object -> "thee".
    {
        minLevel = 2,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap)
            if cur ~= "you" then return nil end
            local verbs = {
                are=true, art=true, have=true, hast=true, will=true,
                shall=true, must=true, can=true, may=true, ["do"]=true,
                dost=true, know=true, knowest=true, see=true, think=true,
                speak=true, come=true, ["go"]=true, want=true, need=true,
                desire=true, require=true,
                -- modal auxiliaries signal "you" is the SUBJECT of the verb
                -- they introduce ("you would help", "you should know")
                would=true, could=true, should=true, might=true,
                ["shall"]=true, ["must"]=true,
            }
            -- common irregular past-tense / present verbs that signal "you"
            -- is the SUBJECT ("you said", "you knew", "you gave")
            local pastVerbs = {
                said=true, told=true, saw=true, knew=true, did=true,
                went=true, gave=true, took=true, made=true, came=true,
                got=true, had=true, were=true, was=true, found=true,
                left=true, felt=true, thought=true, brought=true,
                heard=true, kept=true, held=true, lost=true, won=true,
                ran=true, ["are"]=true, ["have"]=true, lied=true,
            }
            local aux = {
                are=true, art=true, were=true, ["do"]=true, dost=true,
                will=true, shall=true, can=true, may=true, must=true,
                have=true, hast=true, would=true, could=true, should=true,
                -- inverted-question openers: "Did you...", "Does you...",
                -- "Hast thou..." -> the "you" right after is the SUBJECT.
                ["did"]=true, does=true, didst=true, hath=true, has=true,
            }
            local subject = isFirst or EndsClause(prevGap)
            if not subject and nxt and verbs[nxt] then subject = true end
            if not subject and nxt and pastVerbs[nxt] then subject = true end
            -- regular past tense "you <verb>ed" (you walked, you stopped)
            if not subject and nxt and #nxt > 3 and nxt:match("ed$") then
                subject = true
            end
            if not subject and prev and aux[prev] then subject = true end
            return subject and "thou" or "thee"
        end,
    },
    -- Verb agreement after "thou": "thou are" -> "thou art".
    {
        minLevel = 2,
        fn = function(prev, cur)
            if prev == "thou" then
                if cur == "are" then return "art" end
                if cur == "were" then return "wert" end
                if cur == "have" then return "hast" end
                if cur == "will" then return "shalt" end
                if cur == "do" then return "dost" end
                if cur == "shall" then return "shalt" end
                if cur == "would" then return "wouldst" end
                if cur == "could" then return "couldst" end
                if cur == "should" then return "shouldst" end
                if cur == "can" then return "canst" end
                if cur == "has" then return "hast" end
                if cur == "did" then return "didst" end
            end
            return nil
        end,
    },
    -- "your" -> "thy" before consonant, "thine" before vowel/h.
    {
        minLevel = 2,
        fn = function(prev, cur, nxt)
            if cur == "your" and nxt then
                if nxt:match(VOWEL_START) or nxt:sub(1,1):lower() == "h" then
                    return "thine"
                end
                return "thy"
            elseif cur == "your" then
                return "thy"
            end
            return nil
        end,
    },
    -- Greetings as openers only: "hello/hi" at sentence start -> "Well met";
    -- mid-sentence left alone (the flat list still covers a bare greeting).
    {
        minLevel = 1,
        fn = function(prev, cur, nxt, isFirst)
            if isFirst and (cur == "hello" or cur == "hi") then
                return "well met"
            end
            return nil
        end,
    },
    -- Verb swaps that only make sense WITHOUT a following particle.
    -- "look" -> "behold", but NOT "look at" (which would give "behold at").
    -- "go" -> "venture forth", but NOT "go now/home/to..." (reads oddly).
    -- "come" -> "approach", but "come here" collapses to a single "approach".
    -- particles that signal the verb is taking an object/adverb after it:
    {
        -- DEFENSIVE: also match a stale "behold" from an un-pruned flat rule
        -- so "behold at the gate" is repaired back to "look at the gate".
        minLevel = 3,
        fn = function(prev, cur, nxt)
            if cur == "look" or cur == "behold" then
                local particle = {
                    at=true, ["for"]=true, ["into"]=true, out=true,
                    over=true, around=true, after=true, up=true, upon=true,
                }
                if nxt and particle[nxt] then
                    -- particle follows: "behold" reads wrong; restore "look".
                    if cur == "behold" then return "look" end
                    return nil
                end
                return "behold"
            end
            return nil
        end,
    },
    {
        -- "go" -> "venture forth" only for a bare/standalone "go" (end of
        -- clause or before a conjunction). Anything else ("go now", "go to",
        -- "go home") keeps "go" so it stays readable.
        --
        -- DEFENSIVE: a stale flat rule may have already produced "venture
        -- forth" (two tokens). We can't un-merge two tokens here, but we can
        -- prevent the OTHER half-broken case: a stale "venture" stranded
        -- before a particle. The flat list never emitted a bare "venture",
        -- so we only need to gate the live "go" transform.
        minLevel = 3,
        fn = function(prev, cur, nxt)
            if cur == "go" then
                local ok = (nxt == nil) or nxt == "and" or nxt == "with"
                           or nxt == "forth"
                if ok then return "venture forth" end
            end
            return nil
        end,
    },
    {
        minLevel = 3,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap, toks, i)
            if cur ~= "come" then return nil end
            -- "come here" -> single "approach" (drop the "here")
            if nxt == "here" then
                toks[i+1].w = ""
                toks[i+1].g = ""
                return "approach"
            end
            -- bare "come" / "come with" -> "approach"; leave "come to/from" etc.
            local ok = (nxt == nil) or nxt == "with" or nxt == "and"
            if ok then return "approach" end
            return nil
        end,
    },
    -- "fight" -> archaic forms, but agreement matters:
    --   * as a noun ("the fight", "a fight") -> leave it.
    --   * as a transitive verb with an object ("fight the enemy") -> "battle"
    --     ("battle the foe"), since "do battle the foe" is ungrammatical.
    --   * intransitive ("let us fight", "fight on") -> "do battle".
    {
        minLevel = 3,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap)
            if cur ~= "fight" then return nil end
            local determiner = {
                the=true, a=true, an=true, this=true, that=true,
                ["your"]=true, thy=true, thine=true, my=true, mine=true,
                his=true, her=true, our=true, their=true,
            }
            -- noun use -> leave unchanged
            if prev and determiner[prev] then return nil end
            -- transitive: an object (determiner/pronoun/noun) follows -> "battle"
            local objStart = {
                the=true, a=true, an=true, this=true, that=true, these=true,
                those=true, ["your"]=true, thy=true, thine=true, my=true,
                mine=true, his=true, her=true, our=true, their=true,
                them=true, him=true, ["it"]=true, us=true, thee=true,
            }
            if nxt and objStart[nxt] then return "battle" end
            -- otherwise intransitive
            return "do battle"
        end,
    },
    -- "killed" -> "slew" (simple past), not "slain" (which needs an
    -- auxiliary: "has slain"). So "who killed my brother" -> "who slew...".
    {
        minLevel = 3,
        fn = function(prev, cur)
            if cur == "killed" then
                -- if preceded by have/has/had/was/were -> participle "slain"
                local aux = { have=true, has=true, had=true, was=true,
                              were=true, been=true, hast=true, hath=true }
                if prev and aux[prev] then return "slain" end
                return "slew"
            end
            return nil
        end,
    },
    -- "stop" -> "cease" only when intransitive: at end of clause, or before
    -- a gerund ("stop running" -> "cease running"). With an object ("stop
    -- me", "stop the ship") it stays "stop", since "cease me" is wrong.
    --
    -- DEFENSIVE: also match a stale "cease" from an un-pruned flat rule and
    -- revert it to "stop" in transitive position ("cease me" -> "stop me").
    {
        minLevel = 3,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap)
            if cur ~= "stop" and cur ~= "cease" then return nil end
            local intransitive = isLast or EndsClause(curGap)
                                 or (nxt ~= nil and nxt:match("ing$") ~= nil)
            if intransitive then return "cease" end
            if cur == "cease" then return "stop" end
            return nil
        end,
    },
    -- "give" -> "bestow" only when it reads well: "give X" with no indirect
    -- object. "give me the money" -> stays "give" (bestow needs "upon me").
    -- We transform only "give up/give in/give thanks" style and bare uses.
    {
        -- DEFENSIVE: also match a stale "bestow" from an un-pruned flat rule
        -- and revert it to "give" before an object pronoun ("bestow me" is
        -- wrong; "give me" is right).
        minLevel = 3,
        fn = function(prev, cur, nxt)
            if cur == "give" or cur == "bestow" then
                -- leave/restore "give" before an object pronoun (me/us/him...)
                local pron = { me=true, us=true, him=true, her=true,
                               them=true, thee=true, ["it"]=true, you=true }
                if nxt and pron[nxt] then
                    if cur == "bestow" then return "give" end
                    return nil
                end
                return "bestow"
            end
            return nil
        end,
    },
    -- "are thou" -> "art thou" (question/inversion order). The existing
    -- agreement rule handles "thou are"; this handles "are ... thou".
    {
        minLevel = 2,
        fn = function(prev, cur, nxt)
            if cur == "are" and nxt == "thou" then return "art" end
            return nil
        end,
    },
    -- Inverted auxiliary agreement: "do/can/will/shall/have thou" ->
    -- "dost/canst/wilt/shalt/hast thou" (e.g. "Can thou" -> "Canst thou",
    -- "What do thou" -> "What dost thou").
    {
        minLevel = 2,
        fn = function(prev, cur, nxt)
            if nxt ~= "thou" then return nil end
            local inv = {
                ["do"]="dost", ["did"]="didst", does="dost", can="canst",
                will="wilt", shall="shalt", have="hast", has="hast",
                were="wert", would="wouldst", could="couldst",
                should="shouldst", must="must", may="mayst", art="art",
            }
            if inv[cur] then return inv[cur] end
            return nil
        end,
    },
    -- "thou <verb>" base-form agreement for a couple of high-frequency
    -- verbs so "thou know" -> "thou knowest", "thou think" -> "thou thinkest".
    -- Skipped when an auxiliary precedes "thou" ("didst thou see" keeps the
    -- bare "see", since the auxiliary already carries the inflection).
    {
        minLevel = 3,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap, toks, i)
            if prev ~= "thou" then return nil end
            -- look at the token before "thou" (two back from cur)
            local before = (i >= 3) and Core(toks[i-2].w):lower() or nil
            local auxBefore = {
                didst=true, dost=true, canst=true, wilt=true, shalt=true,
                hast=true, wouldst=true, couldst=true, shouldst=true,
                mayst=true, wert=true, ["did"]=true, ["do"]=true,
                can=true, will=true, shall=true,
            }
            if before and auxBefore[before] then return nil end
            local conj = {
                know="knowest", think="thinkest", see="seest",
                speak="speakest", have="hast", shall="shalt",
                will="shalt", ["do"]="dost", say="sayest", make="makest",
            }
            if conj[cur] then return conj[cur] end
            return nil
        end,
    },
}

-- ===== GOBLIN =====
-- Flat list already handles the big multi-word contractions well
-- (whaddya, gonna, gotta). We only add a couple of flow helpers.
CONTEXT_RULES.Goblin = {
    -- "going to <verb>" -> "gonna <verb>", but keep "going to <place>"
    -- intact ("gonna da store" is wrong). Owns the collapse entirely now
    -- that the flat "going to"->"gonna" rule is removed, so it can see the
    -- word after "to" and decide. Fires at L1+ since Goblin is always fast.
    {
        minLevel = 1,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap, toks, i)
            if (cur == "going" or cur == "goin'" or cur == "goin")
               and nxt == "to" and not EndsClause(curGap) then
                local next2 = toks[i+2] and Core(toks[i+2].w):lower() or nil
                if GoingToIsPrepositional(next2) then
                    return nil
                end
                toks[i+1].w = ""
                if toks[i+1].g and toks[i].g == " " then
                    toks[i].g = toks[i+1].g
                    toks[i+1].g = ""
                end
                return "gonna"
            end
            return nil
        end,
    },
    -- "lookit" already bakes in the particle ("look at" -> "lookit"), so a
    -- following "at" is redundant: "lookit at da wall" -> "lookit da wall".
    -- The flat rule turns bare "look" -> "lookit" before this runs; we just
    -- drop a stranded "at" directly after it. "lookit for/around/out" etc.
    -- are left alone (those keep their particle).
    {
        minLevel = 1,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap, toks, i)
            if cur == "lookit" and nxt == "at" then
                toks[i+1].w = ""
                toks[i+1].g = ""
            end
            return nil
        end,
    },
    -- "and" -> "an'" connective at L2+ for that fast-talker cadence.
    {
        minLevel = 2,
        fn = function(prev, cur)
            if cur == "and" then return "an'" end
            return nil
        end,
    },
    -- "to" -> "ta" mid-sentence at full ("gonna talk ta ya").
    {
        minLevel = 3,
        fn = function(prev, cur, nxt, isFirst)
            if cur == "to" and not isFirst then return "ta" end
            return nil
        end,
    },
    -- De-double pronoun after "whaddya". The flat rule "what are" ->
    -- "whaddya" leaves the original "you" behind, which then becomes
    -- "youse", giving "whaddya youse doing". "whaddya" already MEANS
    -- "what are you", so drop the redundant following pronoun. Runs at
    -- L1+ because seeded flat rules fire regardless of their display tier,
    -- so "whaddya" can appear as soon as the dialect is active.
    {
        minLevel = 1,
        fn = function(prev, cur, nxt, isFirst, isLast, prevGap, curGap, toks, i)
            if (cur == "you" or cur == "youse") and prev == "whaddya" then
                -- fold this token's gap onto the previous token and remove it
                toks[i-1].g = toks[i].g or ""
                toks[i].w = ""
                toks[i].g = ""
                return nil
            end
            return nil
        end,
    },
}

-- Public accessor so Apply() can fetch a dialect's context rules.
local function GetContextRules(dialectKey)
    return CONTEXT_RULES[dialectKey]
end

-- ============================================================
-- Drunk slur engine — modelled closely on WoW's own Tipsy → Smashed
-- progression (inebriation levels 1-3 in the game client).
--
-- Design goal: stay subtle and readable. WoW's drunk text is mostly an
-- occasional 's'→'sh' slip plus the odd *hic!*, NOT a wall of stretched
-- vowels and random capitals. Each tier below leans light, adds almost no
-- length, and never touches capitalisation — so messages read as a person
-- slurring slightly, not as keyboard noise.
--
--  Level 1 – Tipsy:   Rare 's'→'sh' between letters. Otherwise clean.
--  Level 2 – Drunk:   Word-initial s→sh sometimes, occasional th→d,
--                     a light vowel stretch here and there.
--  Level 3 – Smashed: s→sh more often, th→d more often, a slightly
--                     stronger (but still bounded) vowel stretch and the
--                     rare dropped final consonant.
-- ============================================================

-- Tipsy: only the subtlest slipping — 's' between two letters occasionally
-- becomes 'sh'. Nothing else.
local function DrunkSlurLevel1(text)
    -- s between two word-chars → sh (15% chance, WoW tipsy feel)
    text = text:gsub("([%a])([Ss])([%a])", function(b, s, a)
        if math.random(1,100) <= 15 then
            return b .. (s=="S" and "Sh" or "sh") .. a
        end
        return b .. s .. a
    end)
    return text
end

-- Drunk: word-initial s→sh sometimes, occasional th→d, and a light vowel
-- stretch. No random caps, no consonant doubling — keeps it readable.
local function DrunkSlurLevel2(text)
    -- Word-initial S/s → Sh/sh (30% chance)
    text = text:gsub("(%s)([Ss])([%a])", function(sp, s, a)
        if math.random(1,100) <= 30 then
            return sp .. (s=="S" and "Sh" or "sh") .. a
        end
        return sp .. s .. a
    end)
    -- Sentence-start S (very beginning of string)
    text = text:gsub("^([Ss])([%a])", function(s, a)
        if math.random(1,100) <= 30 then
            return (s=="S" and "Sh" or "sh") .. a
        end
        return s .. a
    end)
    -- Mid-word s between letters → sh (18%)
    text = text:gsub("([%a])([Ss])([%a])", function(b, s, a)
        if math.random(1,100) <= 18 then return b .. (s=="S" and "Sh" or "sh") .. a end
        return b .. s .. a
    end)
    -- th/Th → d/D (18%)
    text = text:gsub("([Tt]h)", function(th)
        if math.random(1,100) <= 18 then
            return th:sub(1,1)=="T" and "D" or "d"
        end
        return th
    end)
    -- Light vowel stretch (~6%, double only)
    text = text:gsub("([aeiouAEIOU])", function(v)
        if math.random(1,100) <= 6 then return v..v end
        return v
    end)
    return text
end

-- Smashed: near-total S→Sh, heavy th→d, aggressive vowel stretch,
-- word-initial vowel gets a leading 'w', random caps chaos, occasional
-- dropped letter (mirrors WoW's smashed text very closely).

-- Per-word slur with a STRICT growth budget. The old per-character approach
-- let a long word accumulate many independent stretches/doublings, so
-- "Behavior" could balloon into "BeeHaavviiiOoor" and long messages blew past
-- WoW's 255-byte chat limit (causing drops and flood/rate-limiting). This
-- helper caps how many length-ADDING effects any single word may receive,
-- scaled to the word's length, so growth stays bounded and Blizzard-like.
--   maxGrowFrac : max fraction of the word's letters that may be lengthened
--   doubleOnly  : if true, never produce triples (used by lighter tiers)
local function DrunkSlurWord(word, opts)
    opts = opts or {}
    local letters = select(2, word:gsub("%a", ""))
    if letters == 0 then return word end

    -- Budget: at most this many length-adding effects for the whole word.
    -- e.g. a 4-letter word at 0.34 -> 1 effect; a 9-letter word -> 3.
    local budget = math.max(1, math.floor(letters * (opts.maxGrowFrac or 0.34) + 0.5))

    -- s -> sh
    if opts.shChance and opts.shChance > 0 then
        word = word:gsub("([Ss])", function(s)
            if math.random(1,100) <= opts.shChance then
                return s == "S" and "Sh" or "sh"
            end
            return s
        end)
    end
    -- th -> d
    if opts.thChance and opts.thChance > 0 then
        word = word:gsub("([Tt]h)", function(th)
            if math.random(1,100) <= opts.thChance then
                return th:sub(1,1) == "T" and "D" or "d"
            end
            return th
        end)
    end

    -- Length-adding pass: walk characters, spend from the shared budget.
    -- Vowels may stretch, consonants may double, but only up to `budget`
    -- total additions regardless of word length.
    if budget > 0 and (opts.vowelChance or opts.consChance) then
        local out, spent = {}, 0
        for i = 1, #word do
            local ch = word:sub(i, i)
            local added = false
            if spent < budget and ch:match("[aeiouAEIOU]") and opts.vowelChance then
                if math.random(1,100) <= opts.vowelChance then
                    if not opts.doubleOnly and opts.tripleChance
                       and math.random(1,100) <= opts.tripleChance then
                        out[#out+1] = ch .. ch .. ch
                    else
                        out[#out+1] = ch .. ch
                    end
                    spent = spent + 1
                    added = true
                end
            elseif spent < budget and ch:match("[bcdfghjklmnpqrtvwxyzBCDFGHJKLMNPQRTVWXYZ]")
                   and opts.consChance then
                if math.random(1,100) <= opts.consChance then
                    out[#out+1] = ch .. ch
                    spent = spent + 1
                    added = true
                end
            end
            if not added then out[#out+1] = ch end
        end
        word = table.concat(out)
    end

    -- Word-final consonant occasionally dropped (shortens — relieves length).
    if opts.dropChance and opts.dropChance > 0 and letters >= 4 then
        local dropped = word:gsub("([bcdfghjklmnpqrtvwxyzBCDFGHJKLMNPQRTVWXYZ])$", function(c)
            if math.random(1,100) <= opts.dropChance then return "" end
            return c
        end)
        if dropped ~= "" and dropped:match("%a") then word = dropped end
    end

    -- Random caps (case flip only — adds no length).
    if opts.capsChance and opts.capsChance > 0 then
        word = word:gsub("(%a)", function(c)
            if math.random(1,100) <= opts.capsChance then
                return c == c:upper() and c:lower() or c:upper()
            end
            return c
        end)
    end

    return word
end

local function DrunkSlurLevel3(text)
    -- Process word-by-word so the growth budget applies per word and total
    -- length stays controlled. Tuned to stay readable — closer to WoW's
    -- smashed text than to keyboard mashing.
    text = text:gsub("(%S+)", function(word)
        return DrunkSlurWord(word, {
            shChance     = 35,
            thChance     = 25,
            vowelChance  = 12,   -- chance a vowel stretches (within budget)
            tripleChance = 0,    -- doubles only — no triples
            consChance   = 0,    -- no consonant doubling
            maxGrowFrac  = 0.25, -- cap total additions to ~1/4 of letters
            dropChance   = 8,
            capsChance   = 0,    -- never flip case
        })
    end)
    return text
end

local function DrunkSlur(text, level)
    if not text or text == "" then return text end
    local original = text
    if     level == 1 then text = DrunkSlurLevel1(text)
    elseif level == 2 then text = DrunkSlurLevel2(text)
    elseif level >= 3 then text = DrunkSlurLevel3(text)
    end
    -- Safety: never return empty or whitespace-only text
    if not text or text == "" or not text:match("%S") then
        return original
    end
    -- Cap length to stay within WoW's 255-char message limit
    if #text > 250 then
        text = text:sub(1, 250)
        local lastSpace = text:match(".*()%s")
        if lastSpace and lastSpace > 200 then
            text = text:sub(1, lastSpace - 1)
        end
    end
    return text
end

-- Name slurring: leave alone at Tipsy, light s→sh at Drunk,
-- a single light vowel stretch at Smashed — keeps names recognisable.
local function SlurName(name, level)
    if level <= 1 then return name end
    local result = name:gsub("([Ss])", function(s)
        if math.random(1,100) <= 20 then return s=="S" and "Sh" or "sh" end
        return s
    end)
    if level >= 3 then
        result = result:gsub("([aeiouAEIOU])", function(v)
            if math.random(1,100) <= 12 then return v..v end
            return v
        end, 1)
    end
    return result
end

-- ============================================================
-- DIALECT: Drunk
-- ============================================================
local HICCUPS_LIGHT  = {"*hic*"}
local HICCUPS_MEDIUM = {"*hic*", "*hic!*"}
local HICCUPS_FULL   = {"*hic*", "*hic!*", "*hiccup*"}

RegisterDialect("Drunk", {
    name = "Drunk",
    usesSlider = true,
    sliderLabels = {"Off", "Tipsy", "Drunk", "Smashed"},
    sliderColors = {
        {0.55, 0.55, 0.55},
        {0.9, 0.85, 0.3},
        {1.0, 0.55, 0.2},
        {1.0, 0.25, 0.25},
    },
    substitutes = nil,
    slur = function(text, level) return DrunkSlur(text, level) end,
    slurName = function(name, level) return SlurName(name, level) end,
    interjections = {
        [1] = HICCUPS_LIGHT,
        [2] = HICCUPS_MEDIUM,
        [3] = HICCUPS_FULL,
    },
    interjectionChance    = {[1]=4,  [2]=8,  [3]=12},
    interjectionEndChance = {[1]=8,  [2]=15, [3]=22},
})

-- ============================================================
-- DIALECT: Pirate
-- Single-word substitutions only — no multi-word replacements,
-- no doubled words.  Keeps speech flavourful without going over-the-top.
-- ============================================================
RegisterDialect("Pirate", {
    name        = "Pirate",
    usesSlider  = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5,  0.8,  0.5},
        {0.85, 0.65, 0.2},
        {0.75, 0.5,  0.15},
        {0.65, 0.35, 0.1},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur        = nil,
    interjections = nil,
})

-- ============================================================
-- DIALECT: Gilnean (British / Cockney accent)
-- ============================================================
RegisterDialect("Gilnean", {
    name = "Gilnean",
    usesSlider = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.55, 0.75, 1.0},
        {0.4, 0.6, 1.0},
        {0.3, 0.45, 1.0},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur = nil,
    interjections = nil,
})

-- ============================================================
-- DIALECT: Lordaeron (Formal / Archaic)
-- ============================================================
RegisterDialect("Lordaeron", {
    name = "Lordaeron",
    usesSlider = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.85, 0.75, 0.5},
        {0.75, 0.65, 0.35},
        {0.65, 0.55, 0.2},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur = nil,
    interjections = nil,
})

-- ============================================================
-- DIALECT: Goblin
-- ============================================================
RegisterDialect("Goblin", {
    name = "Goblin",
    usesSlider = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.4, 0.85, 0.4},
        {0.3, 0.75, 0.3},
        {0.2, 0.65, 0.2},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur = nil,
    interjections = nil,
})

-- ============================================================
-- DIALECT: Troll (Darkspear / Zandalari accent)
-- ============================================================
RegisterDialect("Troll", {
    name = "Troll",
    usesSlider = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.3, 0.85, 0.65},
        {0.2, 0.75, 0.55},
        {0.1, 0.65, 0.45},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur = nil,
    interjections = nil,
})

-- ============================================================
-- Built-in substitution seed data
-- These are the factory defaults for each dialect's word rules.
-- They are written into Speaketh_Char.dialectSubstitutes once on
-- first load, after which users can freely edit, add, or remove them.
-- The {from, to, minLevel} format is preserved so the UI can show
-- which intensity tier each rule originally belonged to.
-- ============================================================
local BUILTIN_SUBSTITUTES = {
    Pirate = {
        -- Level 1: common swaps a pirate would always use
        {"my",          "me",           1},
        {"the",         "tha",          1},
        {"yes",         "aye",          1},
        {"yeah",        "aye",          1},
        -- is/are -> be handled contextually (only before articles/possessives)
        {"hello",       "ahoy",         1},
        {"hi",          "ahoy",         1},
        {"hey",         "ahoy",         1},
        {"you",         "ye",           1},
        {"your",        "yer",          1},
        {"friend",      "mate",         1},
        {"friends",     "mates",        1},
        -- stop -> belay handled contextually (only when intransitive)
        {"before",      "afore",        2},
        {"after",       "aft",          2},
        {"old",         "barnacled",    2},
        {"find",        "spy",          2},
        {"finding",     "spying",       2},
        {"looking",     "spying",       2},
        -- bare "look" -> spy handled contextually (consumes "look at")
        {"know",        "ken",          2},
        {"of",          "o'",           2},
        {"over",        "o'er",         2},
        {"ever",        "e'er",         2},
        {"never",       "ne'er",        2},
        {"money",       "doubloons",    2},
        {"gold",        "plunder",      2},
        {"ship",        "vessel",       2},
        {"man",         "scallywag",    2},
        {"person",      "landlubber",   2},
        {"drink",       "grog",         2},
        {"drinking",    "swiggin'",     2},
        {"drank",       "swilled",      2},
        -- Level 3: full-tilt sea-dog
        {"idiot",       "bilgerat",     3},
        {"fool",        "swab",         3},
        {"traitor",     "bilgerat",     3},
        {"enemy",       "scoundrel",    3},
        {"enemies",     "scoundrels",   3},
        {"die",         "perish",       3},
        {"dead",        "drowned",      3},
        {"steal",       "plunder",      3},
        {"stolen",      "plundered",    3},
        {"lie",         "hornswoggle",  3},
        {"lied",        "hornswoggled", 3},
        {"crying",      "blawin'",      3},
        {"tired",       "weary",        3},
        {"magic",       "witchcraft",   3},
        {"fight",       "skirmish",     3},
        {"fighting",    "skirmishin'",  3},
        {"run",         "flee",         3},
        {"running",     "fleeing",      3},
        {"great",       "grand",        3},
        {"good",        "fine",         3},
        {"bad",         "foul",         3},
        {"stupid",      "addled",       3},
        {"crazy",       "addled",       3},
        {"land",        "shore",        3},
        {"sea",         "brine",        3},
        {"captain",     "cap'n",        3},
        {"going",       "sailin'",      3},
        {"leaving",     "departin'",    3},
        {"coming",      "arrivin'",     3},
    },
    Gilnean = {
        {"hi",          "oi",               1},
        {"hey",         "oi",               1},
        {"hello",       "'ello",            1},
        {"hiya",        "'eya",             1},
        {"yes",         "aye",              1},
        {"you",         "ya'",              1},
        {"your",        "yer",              1},
        {"my",          "me",               1},
        {"friend",      "mate",             1},
        {"friends",     "mates",            1},
        {"right",       "roight",           1},
        {"alright",     "a'roight",         1},
        {"good",        "proper",           1},
        {"isn't",       "ain't",            1},
        {"aren't",      "ain't",            1},
        {"talk",        "gab",              1},
        {"talking",     "gabbin'",          1},
        {"trash",       "rubbish",          1},
        {"what",        "wot",              2},
        {"whatever",    "wotever",          2},
        {"what's",      "wot's",            2},
        {"was",         "wus",              2},
        {"were",        "wus",              2},
        {"wasn't",      "wusn't",           2},
        {"never",       "niver",            2},
        {"not",         "no'",              2},
        {"nothing",     "nuffin",           2},
        {"something",   "sumfin",           2},
        {"anything",    "anyfing",          2},
        {"everything",  "everyfin",         2},
        {"think",       "fink",             2},
        {"thinking",    "finkin'",          2},
        {"thought",     "fought",           2},
        {"thing",       "fing",             2},
        {"things",      "fings",            2},
        {"with",        "wif",              2},
        {"without",     "wifout",           2},
        {"going",       "goin'",            2},
        {"coming",      "comin'",           2},
        {"doing",       "doin'",            2},
        {"looking",     "lookin'",          2},
        {"getting",     "gettin'",          2},
        {"fighting",    "fightin'",         2},
        {"running",     "runnin'",          2},
        {"little",      "li'l",             2},
        {"old",         "ol'",              2},
        {"about",       "'bout",            2},
        {"you'd",       "yah'd",            3},
        {"you'll",      "ya'll",            3},
        {"you're",      "ya're",            3},
        {"you've",      "ya've",            3},
        {"yourself",    "ya'self",          3},
        {"there",       "dere",             3},
        {"their",       "dere",             3},
        {"they're",     "dey're",           3},
        {"them",        "'em",              3},
        -- the -> da handled contextually (before consonants only)
        {"this",        "dis",              3},
        {"that",        "dat",              3},
        {"those",       "dose",             3},
        {"these",       "dese",             3},
        {"have",        "'ave",             3},
        {"having",      "'avin'",           3},
        {"had",         "'ad",              3},
        {"has",         "'as",              3},
        {"where",       "wer",              3},
        {"man",         "bloke",            3},
        {"woman",       "bird",             3},
        {"money",       "quid",             3},
        {"drunk",       "pissed",           3},
        {"food",        "grub",             3},
        {"house",       "gaff",             3},
        {"stupid",      "daft",             3},
        {"crazy",       "barmy",            3},
        {"very",        "right",            3},
        {"really",      "proper",           3},
    },
    Lordaeron = {
        {"hi",          "well met",         1},
        {"hey",         "hail",             1},
        {"hello",       "well met",         1},
        {"bye",         "fare thee well",   1},
        {"goodbye",     "fare thee well",   1},
        {"yes",         "aye",              1},
        {"yeah",        "aye",              1},
        {"no",          "nay",              1},
        {"nope",        "nay",              1},
        {"please",      "prithee",          1},
        {"thanks",      "my thanks",        1},
        {"thank you",   "I am grateful",    1},
        {"ok",          "very well",        1},
        {"okay",        "very well",        1},
        {"sure",        "indeed",           1},
        -- you/thee/thou, your/thy/thine, my/mine handled contextually
        -- (subject vs object, and vowel-agreement)
        {"you're",      "thou art",         2},
        {"you've",      "thou hast",        2},
        {"you'll",      "thou shalt",       2},
        {"yourself",    "thyself",          2},
        {"i'm",         "I am",             2},
        {"i'll",        "I shall",          2},
        {"i've",        "I have",           2},
        {"we'll",       "we shall",         2},
        {"don't",       "do not",           2},
        {"can't",       "cannot",           2},
        {"won't",       "shall not",        2},
        {"isn't",       "is not",           2},
        {"didn't",      "did not",          2},
        {"doesn't",     "does not",         2},
        {"friend",      "companion",        2},
        {"friends",     "companions",       2},
        {"enemy",       "foe",              2},
        {"enemies",     "foes",             2},
        {"sorry",       "forgive me",       2},
        {"maybe",       "mayhaps",          2},
        {"wasn't",      "was not",          3},
        {"aren't",      "are not",          3},
        {"wouldn't",    "would not",        3},
        {"couldn't",    "could not",        3},
        {"shouldn't",   "should not",       3},
        -- fight (verb), kill/killed, give, stop handled contextually below
        -- so nouns and objects don't break ("the fight", "stop me")
        {"fighting",    "battling",         3},
        {"kill",        "slay",             3},
        {"help",        "aid",              3},
        {"want",        "desire",           3},
        {"need",        "require",          3},
        {"probably",    "most assuredly",   3},
        {"awesome",     "most splendid",    3},
        {"cool",        "commendable",      3},
        {"great",       "most excellent",   3},
        {"before",      "ere",              3},
    },
    Goblin = {
        {"you",         "youse",            1},
        {"your",        "ya",               1},
        {"yours",       "yas",              1},
        {"the",         "da",               1},
        {"this",        "dis",              1},
        {"that",        "dat",              1},
        {"with",        "wit",              1},
        {"yes",         "yeah",             1},
        {"hey",         "ay",               1},
        {"hi",          "ay",               1},
        {"hello",       "ay",               1},
        {"guys",        "youse guys",       1},
        {"because",     "'cause",           2},
        {"kind of",     "kinda",            2},
        {"sort of",     "sorta",            2},
        {"want to",     "wanna",            2},
        {"got to",      "gotta",            2},
        {"have to",     "gotta",            2},
        {"a lot",       "a buncha",         2},
        {"lots of",     "a buncha",         2},
        {"these",       "dese",             2},
        {"those",       "dose",             2},
        {"there",       "dere",             2},
        {"them",        "'em",              2},
        {"about",       "'bout",            2},
        {"alright",     "awright",          2},
        {"around",      "'round",           2},
        {"for",         "fer",              2},
        {"friend",      "pal",              2},
        {"buddy",       "pal",              2},
        {"look",        "lookit",           2},
        {"listen",      "lissen",           2},
        {"what are",    "whaddya",          2},
        {"what do you", "wha'chu",          2},
        {"what you",    "wha'chu",          2},
        {"don't you",   "dontcha",          2},
        {"idea",        "idear",            2},
        {"ideas",       "idears",           2},
        {"forget it",   "fuhgeddaboudit",   3},
        {"forget about it", "fuhgeddaboudit", 3},
        {"seriously",   "serious?",         3},
        {"you serious", "youse serious",    3},
        {"are you kidding", "youse kiddin'", 3},
        {"are you kidding me", "youse kiddin' me", 3},
        {"know what i mean", "know wadda mean", 3},
        {"you know",    "y'know",           3},
        {"over here",   "ovah heah",        3},
        {"over there",  "ovah dere",        3},
        {"coffee",      "cawfee",           3},
        {"water",       "watah",            3},
        {"talking",     "tawkin'",          3},
        {"talk",        "tawk",             3},
        {"walking",     "walkin'",          3},
        {"walk",        "wawk",             3},
    },
    Troll = {
        {"hi",          "ey mon",           1},
        {"hey",         "ey mon",           1},
        {"hello",       "ey mon",           1},
        {"yes",         "ya mon",           1},
        {"no",          "nah mon",          1},
        {"okay",        "aight mon",        1},
        {"ok",          "aight mon",        1},
        {"sure",        "ya mon",           1},
        {"friend",      "mon",              1},
        {"man",         "mon",              1},
        {"dude",        "mon",              1},
        {"the",         "da",               1},
        {"this",        "dis",              1},
        {"that",        "dat",              1},
        {"those",       "dose",             2},
        {"these",       "dese",             2},
        {"there",       "dere",             2},
        {"their",       "dere",             2},
        {"they",        "dey",              2},
        {"them",        "dem",              2},
        {"they're",     "dey be",           2},
        {"think",       "tink",             2},
        {"thinking",    "tinkin'",          2},
        {"thought",     "tought",           2},
        {"thing",       "ting",             2},
        {"things",      "tings",            2},
        {"with",        "wit'",             2},
        {"without",     "wit'out",          2},
        {"nothing",     "nuttin'",          2},
        {"something",   "sumtin'",          2},
        {"anything",    "anyting",          2},
        {"everything",  "everyting",        2},
        {"you",         "ya",               2},
        {"your",        "ya",               2},
        {"you're",      "ya be",            2},
        {"my",          "me",               2},
        {"three",       "tree",             2},
        {"through",     "tru",              2},
        {"throw",       "trow",             2},
        {"bye",         "later, mon",       3},
        {"goodbye",     "later, mon",       3},
        {"brother",     "brudda",           3},
        {"brothers",    "bruddas",          3},
        {"other",       "udda",             3},
        {"another",     "anudda",           3},
        {"mother",      "mudda",            3},
        {"father",      "fadda",            3},
        {"going",       "goin'",            3},
        {"coming",      "comin'",           3},
        {"doing",       "doin'",            3},
        {"having",      "havin'",           3},
        {"looking",     "lookin'",          3},
        {"getting",     "gettin'",          3},
        {"fighting",    "fightin'",         3},
        {"running",     "runnin'",          3},
        {"talking",     "talkin'",          3},
        -- is/are/am/was/were -> be handled contextually (tense + position aware)
        {"about",       "'bout",            3},
        {"little",      "likkle",           3},
        {"old",         "ol'",              3},
        {"over",        "ova",              3},
        {"ever",        "eva",              3},
        {"never",       "neva",             3},
        {"before",      "befo'",            3},
        {"you'll",      "ya gonna",         3},
        {"you've",      "ya",               3},
    },
}

-- Seed dialectSubstitutes from built-in tables on first load.
-- Only runs once per character (guarded by dialectSubstitutesSeedVersion).
-- After seeding, users own the data - they can remove, edit, or add rules freely.
local SEED_VERSION = 9  -- bump this to re-seed on future addon versions

-- Rules that USED to be flat defaults but are now handled by the smarter
-- contextual engine. On upgrade we prune these so the flat swap and the
-- context rule don't both fire (which would double-transform or fight).
-- We only remove an entry if BOTH its 'from' and 'to' still match the old
-- factory default - if the user edited the replacement, we leave it alone.
local SUPERSEDED_DEFAULTS = {
    Pirate = {
        { "is",  "be"  },
        { "are", "be"  },
        -- v7: verb swaps moved to particle/object-aware contextual rules
        { "stop", "belay" },
        { "look", "spy"   },
    },
    Lordaeron = {
        { "you",  "thee"  },
        { "your", "thine" },
        { "my",   "mine"  },
        -- v6: verb swaps moved to particle-aware contextual rules
        { "go",        "venture forth" },
        { "come",      "approach"      },
        { "come here", "approach"      },
        { "look",      "behold"        },
        -- v7: more verb swaps moved to context (noun/object/tense aware)
        { "fight",  "do battle" },
        { "killed", "slain"     },
        { "give",   "bestow"    },
        { "stop",   "cease"     },
    },
    Troll = {
        { "is",   "be" },
        { "are",  "be" },
        { "am",   "be" },
        { "was",  "be" },
        { "were", "be" },
    },
    Gilnean = {
        { "the", "da" },
    },
    -- v9: Goblin "going to"->"gonna" was a flat multi-word rule that fired
    -- even before a destination ("gonna da store"). The going-to collapse is
    -- now a context rule that checks the following word, so prune the flat one.
    Goblin = {
        { "going to", "gonna" },
    },
}

-- v8: A second, looser prune. The context engine now fully owns these
-- SOURCE words for each dialect (it re-derives the correct output from
-- grammar regardless of what the stale flat replacement was). So ANY flat
-- rule whose 'from' is one of these is safe to remove on sight, even if the
-- 'to' was tweaked by an intermediate build or hand-edited. This catches the
-- "near-miss" stale entries that the exact-pair prune above leaves behind
-- (the case where a plain /reload didn't fix speech but /sp resetdialects
-- did). We deliberately restrict this to VERBS the engine owns end-to-end,
-- and NOT to grammatical words like my/your/you, where a user may genuinely
-- want a custom flat swap that the engine should not clobber.
local SUPERSEDED_SOURCES = {
    Pirate    = { stop = true, look = true },
    Lordaeron = { stop = true, look = true, give = true,
                  fight = true, killed = true },
}

local function PruneSuperseded()
    if not Speaketh_Char or not Speaketh_Char.dialectSubstitutes then return end
    for dialectKey, removeList in pairs(SUPERSEDED_DEFAULTS) do
        local list = Speaketh_Char.dialectSubstitutes[dialectKey]
        if list then
            local sourceOnly = SUPERSEDED_SOURCES[dialectKey]
            for i = #list, 1, -1 do
                local entry = list[i]
                local from = (entry[1] or ""):lower()
                local to   = (entry[2] or ""):lower()
                local removed = false
                -- Exact-pair prune (preserves user-edited replacements).
                for _, pair in ipairs(removeList) do
                    if from == pair[1] and to == pair[2] then
                        table.remove(list, i)
                        removed = true
                        break
                    end
                end
                -- Source-only prune for context-owned verbs (catches
                -- near-miss / intermediate-build entries the pair match
                -- misses). Safe because the context engine handles these
                -- source words correctly no matter the replacement.
                if not removed and sourceOnly and sourceOnly[from] then
                    table.remove(list, i)
                end
            end
        end
    end
end

function Speaketh_Dialects:SeedSubstitutes()
    if not Speaketh_Char then return end
    if not Speaketh_Char.dialectSubstitutes then
        Speaketh_Char.dialectSubstitutes = {}
    end

    -- ALWAYS prune superseded factory defaults first, regardless of the
    -- seed version. These flat rules must never coexist with the contextual
    -- engine (doing so causes double-firing like "Belay me from winning" or
    -- "I spy at ye"). The prune only removes entries that still EXACTLY match
    -- an old factory default, so user-customised rules are preserved. This
    -- runs every load because a character may have been stamped at the
    -- current version by an intermediate build that still wrote the old
    -- flat rules. It is cheap and idempotent.
    PruneSuperseded()

    local prevVersion = Speaketh_Char.dialectSubstitutesSeedVersion or 0
    if prevVersion >= SEED_VERSION then
        -- Even when already current, make sure the stamp is set and exit
        -- after the prune above has had a chance to clean stale data.
        Speaketh_Char.dialectSubstitutesSeedVersion = SEED_VERSION
        return
    end

    -- Write all built-in entries for any dialect that has none yet,
    -- or whose table is empty (can happen if a prior seed run was interrupted).
    for dialectKey, entries in pairs(BUILTIN_SUBSTITUTES) do
        local existing = Speaketh_Char.dialectSubstitutes[dialectKey]
        if not existing or #existing == 0 then
            Speaketh_Char.dialectSubstitutes[dialectKey] = {}
            for _, e in ipairs(entries) do
                table.insert(Speaketh_Char.dialectSubstitutes[dialectKey], {e[1], e[2]})
            end
        end
    end

    Speaketh_Char.dialectSubstitutesSeedVersion = SEED_VERSION
end

-- Hard reset: wipe and re-seed ALL built-in dialect rule tables from the
-- factory data. Custom (user-created) dialects are left untouched. This is
-- the nuclear option for clearing corrupted/duplicated saved data that the
-- incremental prune can't fully repair. Exposed via /sp resetdialects.
function Speaketh_Dialects:ResetBuiltinSubstitutes()
    if not Speaketh_Char then return 0 end
    if not Speaketh_Char.dialectSubstitutes then
        Speaketh_Char.dialectSubstitutes = {}
    end
    local count = 0
    for dialectKey, entries in pairs(BUILTIN_SUBSTITUTES) do
        Speaketh_Char.dialectSubstitutes[dialectKey] = {}
        for _, e in ipairs(entries) do
            table.insert(Speaketh_Char.dialectSubstitutes[dialectKey], {e[1], e[2]})
            count = count + 1
        end
    end
    -- Run the prune too, so the freshly-seeded factory rules have the
    -- superseded grammatical ones removed (they live in BUILTIN_SUBSTITUTES'
    -- history, not the current table, but this is belt-and-suspenders).
    PruneSuperseded()
    Speaketh_Char.dialectSubstitutesSeedVersion = SEED_VERSION
    return count
end

function Speaketh_Dialects:GetAll()
    return DIALECTS, DIALECT_ORDER
end

function Speaketh_Dialects:GetActive()
    return Speaketh_Char and Speaketh_Char.dialect or nil
end

function Speaketh_Dialects:SetActive(key)
    if not Speaketh_Char then return end
    if key and not DIALECTS[key] then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00[Speaketh]|r Unknown dialect: " .. tostring(key))
        return
    end
    Speaketh_Char.dialect = key
    -- Initialize intensity level if not already stored.
    -- Drunk starts at 0 (off); all others start at 3 (full).
    if key then
        if not Speaketh_Char.dialectLevels then
            Speaketh_Char.dialectLevels = {}
        end
        if not Speaketh_Char.dialectLevels[key] then
            Speaketh_Char.dialectLevels[key] = (key == "Drunk") and 0 or 3
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cffffcc00[Speaketh]|r Dialect set to |cff88ccff%s|r.", DIALECTS[key].name))
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00[Speaketh]|r Dialect cleared.")
    end
end

function Speaketh_Dialects:GetData(key)
    return DIALECTS[key or ""]
end

-- Per-dialect intensity level (0-3)
-- All dialects use a 0-3 slider. Stored level is used directly.
function Speaketh_Dialects:GetLevel(key)
    key = key or self:GetActive()
    if not key then return 0 end
    local d = DIALECTS[key]
    if d and d.usesSlider then
        -- Slider-driven: use stored level, default to 3 for non-Drunk, 0 for Drunk
        local stored = Speaketh_Char and Speaketh_Char.dialectLevels
                       and Speaketh_Char.dialectLevels[key]
        if stored then return stored end
        return (key == "Drunk") and 0 or 3
    else
        -- On/off dialects: always full intensity when active
        return 3
    end
end

function Speaketh_Dialects:SetLevel(key, level)
    if not Speaketh_Char then return end
    if not Speaketh_Char.dialectLevels then
        Speaketh_Char.dialectLevels = {}
    end
    Speaketh_Char.dialectLevels[key] = math.max(0, math.min(3, math.floor(level + 0.5)))
end

-- Back-compat for old drunkLevel
function Speaketh_Dialects:GetDrunkLevel()
    return self:GetLevel("Drunk")
end

function Speaketh_Dialects:SetDrunkLevel(level)
    self:SetLevel("Drunk", level)
end

-- Passthrough helper
local function GetPassthroughSet(langKey)
    if not langKey then return nil end
    local langData = Speaketh_Languages and Speaketh_Languages[langKey]
    if not langData or not langData.passthrough then return nil end
    return langData.passthrough
end

-- ============================================================
-- Apply dialect BEFORE translation
-- ============================================================
function Speaketh_Dialects:Apply(text, langKey)
    local key = self:GetActive()
    if not key then return text end
    local d = DIALECTS[key]
    if not d then return text end
    local original = text

    local level = self:GetLevel(key)
    if level == 0 then return text end

    -- Step 1: word substitutions (all rules live in Speaketh_Char.dialectSubstitutes)
    local custom = Speaketh_Dialects:GetCustomSubstitutes(key)
    if custom and #custom > 0 then
        local customSubs = {}
        for _, entry in ipairs(custom) do
            table.insert(customSubs, {entry[1], entry[2], 1})
        end
        text = ApplySubstitutes(text, customSubs, 1)
    end

    -- Step 1.5: contextual (grammar-aware) rules for built-in dialects.
    -- These run AFTER the flat swaps and only exist in code, so custom
    -- dialects and user-added words are completely unaffected. They use
    -- the dialect's intensity level so flow scales with the slider.
    local ctxRules = GetContextRules(key)
    if ctxRules then
        text = ApplyContextRules(text, ctxRules, level)
        -- Step 1.6: repair a/an agreement after swaps changed the next word.
        -- Only for built-in dialects (those with context rules); custom
        -- dialects keep their output verbatim.
        text = FixArticles(text)
    end

    -- Step 2: slur/mangling
    if d.slur then
        local passthrough = GetPassthroughSet(langKey)
        if passthrough then
            local result = {}
            local pos = 1
            while pos <= #text do
                local ws, we = text:find("[%a'%-]+", pos)
                if ws then
                    if ws > pos then
                        table.insert(result, text:sub(pos, ws - 1))
                    end
                    local word = text:sub(ws, we)
                    if passthrough[word:lower()] then
                        if d.slurName then
                            table.insert(result, d.slurName(word, level))
                        else
                            table.insert(result, word)
                        end
                    else
                        table.insert(result, d.slur(word, level))
                    end
                    pos = we + 1
                else
                    table.insert(result, text:sub(pos))
                    break
                end
            end
            text = table.concat(result)
        else
            text = d.slur(text, level)
        end
    end

    -- Safety: never return empty text after dialect processing
    if not text or text == "" or not text:match("%S") then
        return original
    end

    return text
end

-- ============================================================
-- Apply post-translation interjections
-- ============================================================
function Speaketh_Dialects:ApplyInterjections(text)
    local key = self:GetActive()
    if not key then return text end
    local d = DIALECTS[key]
    if not d or not d.interjections then return text end

    local level = self:GetLevel(key)
    if level == 0 then return text end

    local intTable = d.interjections[level] or d.interjections[1]
    local chance   = (type(d.interjectionChance) == "table")
                     and (d.interjectionChance[level] or 10)
                     or (d.interjectionChance or 10)
    local endChance = (type(d.interjectionEndChance) == "table")
                      and (d.interjectionEndChance[level] or 0)
                      or (d.interjectionEndChance or 0)

    if not intTable or #intTable == 0 then return text end

    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local result = {}
    for i, word in ipairs(words) do
        table.insert(result, word)
        if i < #words and math.random(1,100) <= chance then
            table.insert(result, intTable[math.random(1, #intTable)])
        end
    end

    if endChance > 0 and math.random(1,100) <= endChance then
        table.insert(result, intTable[math.random(1, #intTable)])
    end

    local out = table.concat(result, " ")

    -- Length safety net. WoW silently drops chat messages over 255 bytes and
    -- rapid oversized sends trip the server flood-protection (the rate-limit
    -- the user hit). Slurring + hiccups can push a long line over. If we're
    -- near the limit, first rebuild WITHOUT the added interjections (they're
    -- the cheapest thing to sacrifice), and only hard-trim as a last resort.
    local SAFE = 240  -- leave headroom for any OOC tag / prefix added later
    if #out > SAFE then
        local plain = table.concat(words, " ")
        if #plain <= SAFE then
            return plain
        end
        -- Even the slurred text alone is too long: trim on a word boundary.
        local trimmed = plain:sub(1, SAFE)
        trimmed = trimmed:gsub("%s+%S*$", "")  -- don't cut mid-word
        if trimmed:match("%S") then return trimmed end
        return plain:sub(1, SAFE)
    end

    return out
end

-- ============================================================
-- Display helpers
-- ============================================================
function Speaketh_Dialects:GetDisplayLabel()
    local key = self:GetActive()
    if not key then return "None" end
    local d = DIALECTS[key]
    if not d then return "None" end
    -- Non-slider dialects (always full intensity): just show the name
    if not d.usesSlider then
        return d.name
    end
    local level = self:GetLevel(key)
    if d.sliderLabels and d.sliderLabels[level + 1] then
        return d.name .. ": " .. d.sliderLabels[level + 1]
    end
    return d.name .. ": " .. level
end

function Speaketh_Dialects:GetDisplayColor()
    local key = self:GetActive()
    if not key then return {0.5, 0.8, 0.5} end
    local d = DIALECTS[key]
    if not d then return {0.5, 0.8, 0.5} end
    -- Non-slider dialects: use their last color (full intensity)
    if not d.usesSlider then
        if d.sliderColors and d.sliderColors[4] then
            return d.sliderColors[4]
        end
        return {0.55, 0.75, 1.0}
    end
    local level = self:GetLevel(key)
    if d.sliderColors and d.sliderColors[level + 1] then
        return d.sliderColors[level + 1]
    end
    return {0.55, 0.75, 1.0}
end

function Speaketh_Dialects:GetSliderLabel(key, level)
    local d = DIALECTS[key]
    if d and d.sliderLabels and d.sliderLabels[level + 1] then
        return d.sliderLabels[level + 1]
    end
    return tostring(level)
end

-- ============================================================
-- Custom per-dialect word substitutions (user-defined, saved)
-- ============================================================

-- Return the list of custom substitutes for a dialect key.
-- Each entry is {from, to} (plain strings, case-insensitive matching).
function Speaketh_Dialects:GetCustomSubstitutes(dialectKey)
    if not dialectKey then return {} end
    local sv = Speaketh_Char and Speaketh_Char.dialectSubstitutes
    if not sv then return {} end
    return sv[dialectKey] or {}
end

-- Add a custom substitute. from/to are plain strings.
-- Returns true on success, or nil + errmsg on failure.
function Speaketh_Dialects:AddCustomSubstitute(dialectKey, from, to)
    if not dialectKey or not DIALECTS[dialectKey] then
        return nil, "Unknown dialect."
    end
    from = from and from:gsub("^%s+", ""):gsub("%s+$", "") or ""
    to   = to   and to:gsub("^%s+",  ""):gsub("%s+$",  "") or ""
    if from == "" then return nil, "Word/phrase cannot be empty." end
    if to   == "" then return nil, "Replacement cannot be empty." end
    if #from > 64 or #to > 64 then return nil, "Text too long (max 64 chars)." end

    if not Speaketh_Char then return nil, "Saved variables not ready." end
    if not Speaketh_Char.dialectSubstitutes then
        Speaketh_Char.dialectSubstitutes = {}
    end
    if not Speaketh_Char.dialectSubstitutes[dialectKey] then
        Speaketh_Char.dialectSubstitutes[dialectKey] = {}
    end

    -- Prevent duplicate 'from' entries (case-insensitive)
    local fromLower = from:lower()
    for _, entry in ipairs(Speaketh_Char.dialectSubstitutes[dialectKey]) do
        if entry[1]:lower() == fromLower then
            return nil, "A rule for \"" .. from .. "\" already exists. Remove it first."
        end
    end

    table.insert(Speaketh_Char.dialectSubstitutes[dialectKey], {from, to})
    return true
end

-- Remove a custom substitute by index within a dialect.
function Speaketh_Dialects:RemoveCustomSubstitute(dialectKey, index)
    local sv = Speaketh_Char and Speaketh_Char.dialectSubstitutes
    if not sv or not sv[dialectKey] then return end
    table.remove(sv[dialectKey], index)
end

-- ============================================================
-- Custom dialect management (user-created dialects)
-- ============================================================

-- Register a custom dialect into the live DIALECTS table.
-- Called both when the user creates one and on login to restore saved ones.
local function RegisterCustomDialect(key, name)
    if DIALECTS[key] then return end  -- already registered (built-in or duplicate)
    DIALECTS[key] = {
        name        = name,
        usesSlider  = false,
        substitutes = nil,
        slur        = nil,
        interjections = nil,
    }
    table.insert(DIALECT_ORDER, key)
end

-- Re-register all saved custom dialects from Speaketh_Char into the live table.
-- Called at PLAYER_LOGIN so they survive reloads.
function Speaketh_Dialects:SeedCustomDialects()
    if not Speaketh_Char or not Speaketh_Char.customDialects then return end
    for key, data in pairs(Speaketh_Char.customDialects) do
        RegisterCustomDialect(key, data.name)
    end
end

-- Create a brand new custom dialect. Returns true or nil+err.
function Speaketh_Dialects:AddCustomDialect(name)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return nil, "Dialect name cannot be empty." end
    if #name > 32 then return nil, "Name too long (max 32 characters)." end

    -- Build a safe key from the name
    local key = "Custom_" .. name:gsub("%s+", "_"):gsub("[^%w_]", "")
    if key == "Custom_" then return nil, "Name must contain at least one letter or number." end

    if DIALECTS[key] then return nil, "A dialect named \"" .. name .. "\" already exists." end

    if not Speaketh_Char then return nil, "Saved variables not ready." end
    if not Speaketh_Char.customDialects then Speaketh_Char.customDialects = {} end
    if not Speaketh_Char.dialectSubstitutes then Speaketh_Char.dialectSubstitutes = {} end

    Speaketh_Char.customDialects[key] = { name = name }
    Speaketh_Char.dialectSubstitutes[key] = {}

    RegisterCustomDialect(key, name)
    return true, key
end

-- Remove a custom dialect entirely (data + live registration).
function Speaketh_Dialects:RemoveCustomDialect(key)
    if not Speaketh_Char then return end
    -- Can't remove built-in dialects
    if not (Speaketh_Char.customDialects and Speaketh_Char.customDialects[key]) then
        return nil, "Not a custom dialect."
    end
    -- If it's currently active, clear it
    if Speaketh_Char.dialect == key then
        Speaketh_Char.dialect = nil
    end
    Speaketh_Char.customDialects[key] = nil
    if Speaketh_Char.dialectSubstitutes then
        Speaketh_Char.dialectSubstitutes[key] = nil
    end
    DIALECTS[key] = nil
    for i, k in ipairs(DIALECT_ORDER) do
        if k == key then table.remove(DIALECT_ORDER, i); break end
    end
    return true
end

-- Returns true if a dialect key is user-created (not built-in).
function Speaketh_Dialects:IsCustomDialect(key)
    return Speaketh_Char
        and Speaketh_Char.customDialects
        and Speaketh_Char.customDialects[key] ~= nil
end
