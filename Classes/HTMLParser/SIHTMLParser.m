//
//  SIHTMLParser.m
//  SIParser
//
//  Created by Silence on 2017/8/26.
//  Copyright © 2017年 Silence. All rights reserved.
//

#import "SIHTMLParser.h"
#import "UIColor+Hex.h"

@implementation SIHTMLParser

- (instancetype)init{
    if (self = [super init]) {
        [self setStyles];
        [self setNodeBlocks];
    }
    return self;
}

- (void)setStyles{
    NSDictionary *theStyleAttribute = nil;
    
    //a
    theStyleAttribute = @{ NSForegroundColorAttributeName: [UIColor blueColor],
                           NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                           NSUnderlineColorAttributeName: [UIColor redColor] };
    [self addStyle:theStyleAttribute forTag:@"a"];
    
    //strong 加粗
    theStyleAttribute = @{ NSExpansionAttributeName: @(0.9) };
    [self addStyle:theStyleAttribute forTag:@"strong"];
    
    //mark
    theStyleAttribute = @{ NSForegroundColorAttributeName: [UIColor yellowColor] };
    [self addStyle:theStyleAttribute forTag:@"mark"];
    
    //i 斜体
    theStyleAttribute = @{ NSBackgroundColorAttributeName: [UIColor yellowColor],
                           NSForegroundColorAttributeName: [UIColor redColor],
                           NSObliquenessAttributeName: @(2) };
    [self addStyle:theStyleAttribute forTag:@"i"];
    
    //strike 删除线
    theStyleAttribute = @{ NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle),
                           NSStrikethroughColorAttributeName: [UIColor greenColor] };
    [self addStyle:theStyleAttribute forTag:@"strike"];
    
    //stroke 描边
    theStyleAttribute = @{ NSStrokeColorAttributeName: [UIColor redColor],
                           NSStrokeWidthAttributeName: @(2) };
    [self addStyle:theStyleAttribute forTag:@"stroke"];
}

- (void)setNodeBlocks
{
    SINodeBlock theNodeBlock = nil;
    __weak typeof(self) weakSelf = self;
    
    //img
    theNodeBlock = ^(SINode *node, NSDictionary *defaultStyles) {
        NSString *theSrcString = node.attributes[@"src"];
        UIImage *theImage = (theSrcString.length > 0) ? [UIImage imageNamed:theSrcString] : nil;
        
        NSString *theWidthString = node.attributes[@"width"];
        NSString *theHeightString = node.attributes[@"height"];
        CGRect bounds = CGRectZero;
        if (theWidthString.length > 0 && theHeightString.length > 0) {
            bounds.size.width = [theWidthString floatValue];
            bounds.size.height = [theHeightString floatValue];
        }
        
        NSTextAttachment *theTextAttachment = [[NSTextAttachment alloc] init];
        theTextAttachment.image = theImage;
        if (bounds.size.width > 2 && bounds.size.height > 2) {
            theTextAttachment.bounds = bounds;
        }
        NSAttributedString *theAttributedString = [NSAttributedString attributedStringWithAttachment:theTextAttachment];
        
        return theAttributedString;
    };
    [self addNodeBlock:theNodeBlock forTag:@"img"];
    
    //a
    theNodeBlock = ^(SINode *node, NSDictionary *defaultStyles) {
        NSString *theContent = node.content ?: @"???";
        
        NSMutableDictionary *theStyle = [NSMutableDictionary dictionary];
        if (defaultStyles.count > 0) {
            [theStyle addEntriesFromDictionary:defaultStyles];
        }
        NSString *theHrefString = node.attributes[@"href"];
        if (theHrefString.length > 0) {
            theStyle[NSLinkAttributeName] = [NSURL URLWithString:theHrefString];
        }
        NSAttributedString *theAttributedString = [[NSAttributedString alloc] initWithString:theContent attributes:theStyle];
        
        return theAttributedString;
    };
    [self addNodeBlock:theNodeBlock forTag:@"a"];
    
    //font
    theNodeBlock = ^(SINode *node, NSDictionary *defaultStyles) {
        NSString *theContent = node.content ?: @"";
        
        NSMutableDictionary *theStyle = [NSMutableDictionary dictionary];
        if (defaultStyles.count > 0) {
            [theStyle addEntriesFromDictionary:defaultStyles];
        }
        
        NSString *theColorString = node.attributes[@"color"];
        if (theColorString.length > 0) {
            UIColor *theColor = [UIColor colorWithHexString:theColorString];
            theStyle[NSForegroundColorAttributeName] = theColor;
        }
        
        NSString *theBgColorString = node.attributes[@"bgcolor"];
        if (theBgColorString.length > 0) {
            UIColor *theBgColor = [UIColor colorWithHexString:theBgColorString];
            theStyle[NSBackgroundColorAttributeName] = theBgColor;
        }
        
        NSString *theSizeString = node.attributes[@"size"];
        if (theSizeString.length > 0) {
            NSDictionary *styleDic = weakSelf.stylesMap[@"font"];
            UIFont *styleFont = styleDic[NSFontAttributeName];
            theStyle[NSFontAttributeName] = [UIFont fontWithName:styleFont.fontName size:[theSizeString floatValue]];
        }
        NSAttributedString *theAttributedString = [[NSAttributedString alloc] initWithString:theContent attributes:theStyle];
        
        return theAttributedString;
    };
    [self addNodeBlock:theNodeBlock forTag:@"font"];
}

- (xmlNodePtr)_rootNodeWithData:(NSData *)inData{
    if (inData.length == 0) {
        return NULL;
    }
    
    NSData *theData = inData;
    
    CFStringEncoding cfenc = CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding);
    CFStringRef cfencstr = CFStringConvertEncodingToIANACharSetName(cfenc);
    const char *enc = CFStringGetCStringPtr(cfencstr, 0);
    int optionsHtml = HTML_PARSE_RECOVER;
    optionsHtml = optionsHtml | HTML_PARSE_NOERROR; //Uncomment this to see HTML errors
    optionsHtml = optionsHtml | HTML_PARSE_NOWARNING;
    
    //htmlReadDoc中文乱码; htmlReadMemory字符正常
    htmlDocPtr docPtr = htmlReadMemory(theData.bytes, (int)theData.length, NULL, enc, optionsHtml);
    return xmlDocGetRootElement(docPtr);
}

- (NSDictionary *)_attributesWithXmlNode:(xmlNodePtr)xmlNode{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    
    if (NULL == xmlNode || NULL == xmlNode->name) {
        return attributes;
    }
    
    NSString *tag = [NSString stringWithUTF8String:(char *)xmlNode->name];
    if (tag.length > 0) {
        attributes[@"tag"] = tag;
    }
    
    for (xmlAttrPtr attr = xmlNode->properties; attr; attr = attr->next) {
        NSString *name = nil;
        NSString *value = nil;
        if (attr->name) {
            name = [NSString stringWithUTF8String:(const char *)attr->name];
            SIParserLog(@"attr name: %@", name);
        }
        xmlChar *valueChar = xmlNodeListGetString(xmlNode->doc, attr->children, 1);
        if (valueChar) {
            value = [NSString stringWithUTF8String:(char *)valueChar];
            SIParserLog(@"attr value: %@", value);
        }
        if (name.length > 0 && value.length > 0) {
            attributes[name] = value;
        }
    }
    return attributes;
}

- (void)_readWithNode:(xmlNodePtr)inNode nodeList:(SINodeList *)outNodeList
{
    if (NULL == inNode) {
        return;
    }
    
    xmlNodePtr currentNode = inNode;
    while (currentNode) {
        SINode *theNode = [[SINode alloc] initWithXmlNode:currentNode];
        
        if (currentNode->name) {
            NSString *name = [NSString stringWithUTF8String:(const char *)currentNode->name];
            SIParserLog(@"name: %@", name);
            theNode.name = name;
            [theNode addAttributes:@{@"tag":name}];
        }
        if (currentNode->content) {
            NSString *content = [NSString stringWithUTF8String:(const char *)currentNode->content];
            SIParserLog(@"content: %@", content);
            theNode.content = content;
        }
        for (xmlAttrPtr attr = currentNode->properties; attr; attr = attr->next) {
            NSString *name = nil;
            NSString *value = nil;
            if (attr->name) {
                name = [NSString stringWithUTF8String:(const char *)attr->name];
                SIParserLog(@"attr name: %@", name);
            }
            xmlChar *valueChar = xmlNodeListGetString(currentNode->doc, attr->children, 1);
            if (valueChar) {
                value = [NSString stringWithUTF8String:(char *)valueChar];
                SIParserLog(@"attr value: %@", value);
            }
            if (name.length > 0 && value.length > 0) {
                [theNode addAttributes:@{name:value}];
            }
        }
        if (strcmp((char *)currentNode->name, "text") == 0) {
            [theNode addAttributes:[self _attributesWithXmlNode:currentNode->parent]];
        }
        
        [outNodeList addNode:theNode];
        [self _readWithNode:currentNode->children nodeList:outNodeList];
        currentNode = currentNode->next;
    }
}

- (SINodeList *)nodeListWithString:(NSString *)inString{
    if (inString.length == 0) {
        return nil;
    }
    
    NSData *theData = [inString dataUsingEncoding:NSUTF8StringEncoding];
    xmlNodePtr rootXmlNode = [self _rootNodeWithData:theData];
    SINodeList *theNodeList = [[SINodeList alloc] init];
    [self _readWithNode:rootXmlNode nodeList:theNodeList];
    return theNodeList;
}

- (NSAttributedString *)parseString:(NSString *)inString{
    SINodeList *theNodeList = [self nodeListWithString:inString];
    
    NSMutableAttributedString *theAttrString = [[NSMutableAttributedString alloc] init];
    for (SINode *node in theNodeList.nodes) {
        SIParserLog(@"name: %@, content: %@, attributes: %@", node.name, node.content, node.attributes);
        
        NSString *tag = node.attributes[@"tag"];
        if (tag.length == 0) {
            continue;
        }
        
        NSString *content = node.content;
        NSDictionary *baseAttributes = self.stylesMap[tag];
        SINodeBlock nodeBlock = self.nodeBlocksMap[tag];
        
        NSAttributedString *nodeAttrStr = nil;
        if (nodeBlock) {
            nodeAttrStr = nodeBlock(node, baseAttributes);
        } else if (content.length > 0) {
            nodeAttrStr = [[NSAttributedString alloc] initWithString:content attributes:baseAttributes];
        }
        
        if (nodeAttrStr) {
            [theAttrString appendAttributedString:nodeAttrStr];
        }
    }
    
    return theAttrString;
}


@end
