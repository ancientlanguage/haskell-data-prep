module Prepare.Perseus.TeiEpidocParser where

import Prelude hiding (Word)
import Control.Lens (over, _Just)
import Data.Text (Text)
import qualified Data.Text as Text
import Prepare.Perseus.TeiEpidocModel
import qualified Prepare.Perseus.TeiEpidocHeaderParser as Header
import Prepare.Perseus.TeiEpidocParserCommon
import Prepare.Xml.Parser (NodeParser, (<|>), many, optional)
import qualified Prepare.Xml.Parser as Xml
import qualified Text.Megaparsec.Char as MP
import qualified Text.Megaparsec.Lexer as MP
import qualified Text.Megaparsec.Prim as MP

milestoneParagraph :: NodeParser Milestone
milestoneParagraph = build <$> Xml.elementAttrNS (teiNS "milestone") attributes Xml.end
  where
  build (x, _) = x
  attributes = do
    ed <- Xml.attribute "ed"
    u <- Xml.attribute "unit"
    _ <- Xml.parseNested ("milestone unit para") (MP.string "para") u
    return $ MilestoneParagraph ed

milestoneCard :: NodeParser Milestone
milestoneCard = build <$> Xml.elementAttrNS (teiNS "milestone") attributes Xml.end
  where
  build (x, _) = x
  attributes = do
    n <- Xml.attribute "n"
    num <- Xml.parseNested "milestone card n" MP.integer n
    u <- Xml.attribute "unit"
    _ <- Xml.parseNested "milestone unit card" (MP.string "card") u
    return $ MilestoneCard num

milestone :: NodeParser Milestone
milestone
  = MP.try milestoneParagraph
  <|> milestoneCard

apparatusAdd :: NodeParser ApparatusAdd
apparatusAdd = ApparatusAdd <$> Xml.elementContentNS (teiNS "add")

apparatusDel :: NodeParser ApparatusDel
apparatusDel = ApparatusDel <$> Xml.elementContentNS (teiNS "del")

apparatusCorr :: NodeParser ApparatusCorr
apparatusCorr = ApparatusCorr <$> Xml.elementContentNS (teiNS "corr")

term :: NodeParser Term
term = Term <$> Xml.elementContentNS (teiNS "term")

gap :: NodeParser Gap
gap = build <$> Xml.elementAttrNS (teiNS "gap") (optional $ Xml.attribute "reason") Xml.end
  where
  build (x, _) = Gap x

plainText :: NodeParser Text
plainText = Xml.content

bibl :: NodeParser Bibl
bibl = build <$> Xml.elementContentAttrNS (teiNS "bibl") attributes
  where
  build ((d, n), t) = Bibl n t d
  attributes = do
    d <- optional (Xml.attribute "default")
    n <- optional (Xml.attribute "n")
    return (d, n)

quoteLine :: NodeParser QuoteLine
quoteLine = build <$> Xml.elementContentAttrNS (teiNS "l") attributes
  where
  build ((a, m), c) = QuoteLine m c a
  attributes = do
    a <- optional (Xml.attribute "ana")
    m <- optional (Xml.attribute "met")
    return (a, m)

quote :: NodeParser Quote
quote = build <$> Xml.elementAttrNS (teiNS "quote") attributes children
  where
  build (x, y) = Quote x y
  attributes = Xml.attribute "type"
  children = many quoteLine

cit :: NodeParser Cit
cit = Xml.elementNS (teiNS "cit") (Cit <$> quote <*> bibl)

speaker :: NodeParser Speaker
speaker = Xml.elementNS (teiNS "sp") children
  where
  children = do
    s <- xmlContent "speaker"
    p <- xmlContent "p"
    return $ Speaker s p

speakerContents :: NodeParser [Content]
speakerContents = pure . ContentSpeaker <$> speaker

content :: NodeParser Content
content
  = MP.try (ContentText <$> plainText)
  <|> (ContentAdd <$> apparatusAdd)
  <|> (ContentDel <$> apparatusDel)
  <|> (ContentCorr <$> apparatusCorr)
  <|> (ContentTerm <$> term)
  <|> (ContentMilestone <$> milestone)
  <|> (ContentGap <$> gap)
  <|> (ContentQuote <$> quote)
  <|> (ContentBibl <$> bibl)
  <|> (ContentCit <$> cit)

textPartSubtype :: Text -> Xml.AttributeParser Integer
textPartSubtype v = do
  n <- Xml.attribute "n"
  num <- Xml.parseNested (Text.unpack v ++ " number") MP.integer n
  _ <- Xml.attributeValue "subtype" v
  _ <- Xml.attributeValue "type" "textpart"
  return num

divType :: Text -> Xml.AttributeParser Integer
divType v = do
  n <- Xml.attribute "n"
  num <- Xml.parseNested (Text.unpack v ++ " number") MP.integer n
  _ <- Xml.attributeValue "type" v
  return num

divTypeOrSubtype :: Text -> Xml.AttributeParser Integer
divTypeOrSubtype v
  = MP.try (textPartSubtype v)
  <|> divType v

paragraph :: NodeParser [Content]
paragraph = Xml.elementNS (teiNS "p") (many content)

section :: NodeParser Section
section = build <$> Xml.elementAttrNS (teiNS "div") attributes children
  where
  build (x, y) = Section x y
  attributes = divTypeOrSubtype "section"
  children = concat <$> many (paragraph <|> speakerContents)

chapter :: NodeParser Chapter
chapter = build <$> Xml.elementAttrNS (teiNS "div") attributes children
  where
  build (x, y) = Chapter x y
  attributes = divTypeOrSubtype "chapter"
  children = many section

book :: NodeParser Book
book = build <$> Xml.elementAttrNS (teiNS "div") attributes children
  where
  build (x, (y, z)) = Book x y z
  attributes = divTypeOrSubtype "book"
  children = do
    h <- optional (Xml.elementContentNS (teiNS "head"))
    cs <- many chapter
    return (h, cs)

lineContent :: NodeParser LineContent
lineContent
  = MP.try (LineContentMilestone <$> milestone)
  <|> MP.try (LineContentText <$> plainText)
  <|> (LineContentDel <$> apparatusDel)

line :: NodeParser Line
line = build <$> Xml.elementAttrNS (teiNS "l") attributes children
  where
  build ((n, r), cs) = Line n r cs
  attributes = do
    n <- optional (Xml.attribute "n")
    num <- _Just (Xml.parseNested "line number" MP.integer) n
    rend <- optional (Xml.attribute "rend")
    r <- _Just (Xml.parseNested "line rend" $ MP.string "displayNumAndIndent") rend
    return (num, over _Just (const LineRender_DisplayNumAndIndent) r)
  children = many lineContent

bookLineContent :: NodeParser BookLineContent
bookLineContent
  = MP.try (BookLineContentMilestone <$> milestone)
  <|> (BookLineContentLine <$> line)

bookLines :: NodeParser BookLines
bookLines = build <$> Xml.elementAttrNS (teiNS "div") attributes children
  where
  build (x, y) = BookLines x y
  attributes = divTypeOrSubtype "book"
  children = many bookLineContent

division :: NodeParser Division
division
  = MP.try (DivisionBooks <$> many book)
  <|> MP.try (DivisionChapters <$> many chapter)
  <|> MP.try (DivisionSections <$> many section)
  <|> (DivisionBookLines <$> many bookLines)

edition :: NodeParser Edition
edition = build <$> Xml.elementAttrNS (teiNS "div") attributes children
  where
  build ((n, l), y) = Edition n l y
  attributes = do
    n <- Xml.attribute "n"
    _ <- Xml.attributeValue "type" "edition"
    l <- optional (Xml.attributeXml "lang")
    return (n, l)
  children = division

body :: NodeParser Body
body = Xml.elementNS (teiNS "body") children
  where
  children
    = MP.try (BodyEdition <$> edition)
    <|> (BodyDivision <$> division)

interp :: NodeParser Interp
interp = build <$> Xml.elementContentAttrNS (teiNS "interp") attributes
  where
  build (i, v) = Interp i v
  attributes = Xml.attributeXml "id"

interpGrp :: NodeParser InterpGrp
interpGrp = build <$> Xml.elementAttrNS (teiNS "interpGrp") attributes children
  where
  build ((t, l), v) = InterpGrp t l v
  attributes = do
    t <- Xml.attribute "type"
    l <- Xml.attributeXml "lang"
    return (t, l)
  children = many interp

teiText :: NodeParser TeiText
teiText = build <$> Xml.elementAttrNS (teiNS "text") attributes children
  where
  build ((n, l), (i, b)) = TeiText l b n i
  attributes = do
    n <- optional (Xml.attribute "n")
    l <- optional (Xml.attributeXml "lang")
    return (n, l)
  children = do
    i <- optional interpGrp
    b <- body
    return (i, b)

tei :: NodeParser Tei
tei = Xml.elementNS (teiNS "TEI") children 
  where
  children = pure Tei
    <*> Header.teiHeader
    <*> teiText
