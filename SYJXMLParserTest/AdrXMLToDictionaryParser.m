//
//  AdrXMLToDictionaryParser.m
//  XMLTest
//
//  Created by PA on 15/2/2.
//
//1.0.1

#import "AdrXMLToDictionaryParser.h"

#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma GCC diagnostic ignored "-Wdirect-ivar-access"

@interface AdrXMLToDictionaryParser () <NSXMLParserDelegate>

@property (nonatomic, strong) NSMutableDictionary *root;
@property (nonatomic, strong) NSMutableArray *stack;
@property (nonatomic, strong) NSMutableString *text;

@end

@implementation AdrXMLToDictionaryParser

+ (AdrXMLToDictionaryParser *)sharedInstance
{
    static dispatch_once_t once;
    static AdrXMLToDictionaryParser *sharedInstance;
    dispatch_once(&once, ^{
        
        sharedInstance = [[AdrXMLToDictionaryParser alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    if ((self = [super init]))
    {
        _collapseTextNodes = YES;
        _stripEmptyNodes = YES;
        _trimWhiteSpace = YES;
        _alwaysUseArrays = NO;
        _preserveComments = NO;
        _wrapRootNode = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    AdrXMLToDictionaryParser *copy = [[[self class] allocWithZone:zone] init];
    copy.collapseTextNodes = _collapseTextNodes;
    copy.stripEmptyNodes = _stripEmptyNodes;
    copy.trimWhiteSpace = _trimWhiteSpace;
    copy.alwaysUseArrays = _alwaysUseArrays;
    copy.preserveComments = _preserveComments;
    copy.attributesMode = _attributesMode;
    copy.nodeNameMode = _nodeNameMode;
    copy.wrapRootNode = _wrapRootNode;
    return copy;
}

- (NSDictionary *)getDictionaryWithXMLParser:(NSXMLParser *)parser
{
    [parser setDelegate:self];
    parser.shouldProcessNamespaces = YES;
    [parser parse];
    NSLog(@"%@", [parser.parserError localizedDescription]);
    
    id result = _root;
    _root = nil;
    _stack = nil;
    _text = nil;
    return result;
}

- (NSDictionary *)getDictionaryFromXMLData:(NSData *)data
{
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:data];
    return [self getDictionaryWithXMLParser:xmlParser];
}

- (NSDictionary *)getDictionaryFromXMLString:(NSString *)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self getDictionaryFromXMLData:data];
}

- (void)endText
{
    if (_trimWhiteSpace)
    {
        _text = [[_text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy];
    }
    if ([_text length])
    {
        NSMutableDictionary *top = [_stack lastObject];
        id existing = top[AdrXMLDictionaryTextKey];
        if ([existing isKindOfClass:[NSArray class]])
        {
            [existing addObject:_text];
        }
        else if (existing)
        {
            top[AdrXMLDictionaryTextKey] = [@[existing, _text] mutableCopy];
        }
        else
        {
            top[AdrXMLDictionaryTextKey] = _text;
        }
    }
    _text = nil;
}

- (void)addText:(NSString *)text
{
    if (!_text)
    {
        _text = [NSMutableString stringWithString:text];
    }
    else
    {
        [_text appendString:text];
    }
}

- (void)parser:(__unused NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(__unused NSString *)namespaceURI qualifiedName:(__unused NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [self endText];
    
    NSMutableDictionary *node = [NSMutableDictionary dictionary];
    switch (_nodeNameMode)
    {
        case AdrXMLDictionaryNodeNameModeRootOnly:
        {
            if (!_root)
            {
                node[AdrXMLDictionaryNodeNameKey] = elementName;
            }
            break;
        }
        case AdrXMLDictionaryNodeNameModeAlways:
        {
            node[AdrXMLDictionaryNodeNameKey] = elementName;
            break;
        }
        case AdrXMLDictionaryNodeNameModeNever:
        {
            break;
        }
    }
    
    if ([attributeDict count])
    {
        switch (_attributesMode)
        {
            case AdrXMLDictionaryAttributesModePrefixed:
            {
                for (NSString *key in [attributeDict allKeys])
                {
                    node[[AdrXMLDictionaryAttributePrefix stringByAppendingString:key]] = attributeDict[key];
                }
                break;
            }
            case AdrXMLDictionaryAttributesModeDictionary:
            {
                node[AdrXMLDictionaryAttributesKey] = attributeDict;
                break;
            }
            case AdrXMLDictionaryAttributesModeUnprefixed:
            {
                [node addEntriesFromDictionary:attributeDict];
                break;
            }
            case AdrXMLDictionaryAttributesModeDiscard:
            {
                break;
            }
        }
    }
    
    if (!_root)
    {
        _root = node;
        _stack = [NSMutableArray arrayWithObject:node];
        if (_wrapRootNode)
        {
            _root = [NSMutableDictionary dictionaryWithObject:_root forKey:elementName];
            [_stack insertObject:_root atIndex:0];
        }
    }
    else
    {
        NSMutableDictionary *top = [_stack lastObject];
        id existing = top[elementName];
        if ([existing isKindOfClass:[NSArray class]])
        {
            [existing addObject:node];
        }
        else if (existing)
        {
            top[elementName] = [@[existing, node] mutableCopy];
        }
        else if (_alwaysUseArrays)
        {
            top[elementName] = [NSMutableArray arrayWithObject:node];
        }
        else
        {
            top[elementName] = node;
        }
        [_stack addObject:node];
    }
}

- (void)parser:(__unused NSXMLParser *)parser didEndElement:(__unused NSString *)elementName namespaceURI:(__unused NSString *)namespaceURI qualifiedName:(__unused NSString *)qName
{
    [self endText];
    
    NSMutableDictionary *top = [_stack lastObject];
    [_stack removeLastObject];
    
    if (![self getXMLAttributesWithDic:top] && ![self getXMLChildNodesWithDic:top] && ![self getXMLCommentsWithDic:top])
    {
        NSMutableDictionary *newTop = [_stack lastObject];
        NSString *nodeName = [self nameForNode:top inDictionary:newTop];
        if (nodeName)
        {
            id parentNode = newTop[nodeName];
            if ([self getXMLInnerTextWithDic:top] && _collapseTextNodes)
            {
                if ([parentNode isKindOfClass:[NSArray class]])
                {
                    parentNode[[parentNode count] - 1] = [self getXMLInnerTextWithDic:top];
                }
                else
                {
                    newTop[nodeName] = [self getXMLInnerTextWithDic:top];
                }
            }
            else if (![self getXMLInnerTextWithDic:top] && _stripEmptyNodes)
            {
                if ([parentNode isKindOfClass:[NSArray class]])
                {
                    [parentNode removeLastObject];
                }
                else
                {
                    [newTop removeObjectForKey:nodeName];
                }
            }
            else if (![self getXMLInnerTextWithDic:top] && !_collapseTextNodes && !_stripEmptyNodes)
            {
                top[AdrXMLDictionaryTextKey] = @"";
            }
        }
    }
}

- (void)parser:(__unused NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [self addText:string];
}

- (void)parser:(__unused NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    [self addText:[[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding]];
}

- (void)parser:(__unused NSXMLParser *)parser foundComment:(NSString *)comment
{
    if (_preserveComments)
    {
        NSMutableDictionary *top = [_stack lastObject];
        NSMutableArray *comments = top[AdrXMLDictionaryCommentsKey];
        if (!comments)
        {
            comments = [@[comment] mutableCopy];
            top[AdrXMLDictionaryCommentsKey] = comments;
        }
        else
        {
            [comments addObject:comment];
        }
    }
}

- (NSString *)nameForNode:(NSDictionary *)node inDictionary:(NSDictionary *)dict
{
    if ([self getXMLNodeNameWithDic:node])
    {
        return [self getXMLNodeNameWithDic:node];
    }
    else
    {
        for (NSString *name in dict)
        {
            id object = dict[name];
            if (object == node)
            {
                return name;
            }
            else if ([object isKindOfClass:[NSArray class]] && [object containsObject:node])
            {
                return name;
            }
        }
    }
    return nil;
}

//////////////////nsdic method
- (NSDictionary *)getXMLAttributesWithDic:(NSDictionary *)dic
{
    NSDictionary *attributes = dic[AdrXMLDictionaryAttributesKey];
    if (attributes)
    {
        return [attributes count]? attributes: nil;
    }
    else
    {
        NSMutableDictionary *filteredDict = [NSMutableDictionary dictionaryWithDictionary:dic];
        [filteredDict removeObjectsForKeys:@[AdrXMLDictionaryCommentsKey, AdrXMLDictionaryTextKey, AdrXMLDictionaryNodeNameKey]];
        for (NSString *key in [filteredDict allKeys])
        {
            [filteredDict removeObjectForKey:key];
            if ([key hasPrefix:AdrXMLDictionaryAttributePrefix])
            {
                filteredDict[[key substringFromIndex:[AdrXMLDictionaryAttributePrefix length]]] = dic[key];
            }
        }
        return [filteredDict count]? filteredDict: nil;
    }
}

- (NSDictionary *)getXMLChildNodesWithDic:(NSDictionary *)dic
{
    NSMutableDictionary *filteredDict = [dic mutableCopy];
    [filteredDict removeObjectsForKeys:@[AdrXMLDictionaryAttributesKey, AdrXMLDictionaryCommentsKey, AdrXMLDictionaryTextKey, AdrXMLDictionaryNodeNameKey]];
    for (NSString *key in [filteredDict allKeys])
    {
        if ([key hasPrefix:AdrXMLDictionaryAttributePrefix])
        {
            [filteredDict removeObjectForKey:key];
        }
    }
    return [filteredDict count]? filteredDict: nil;
}

- (NSArray *)getXMLCommentsWithDic:(NSDictionary *)dic
{
    return dic[AdrXMLDictionaryCommentsKey];
}

- (NSString *)getXMLNodeNameWithDic:(NSDictionary *)dic
{
    return dic[AdrXMLDictionaryNodeNameKey];
}

- (id)getXMLInnerTextWithDic:(NSDictionary *)dic
{
    id text = dic[AdrXMLDictionaryTextKey];
    if ([text isKindOfClass:[NSArray class]])
    {
        return [text componentsJoinedByString:@"\n"];
    }
    else
    {
        return text;
    }
}

@end
