//
//  AdrXMLToDictionaryParser.h
//  XMLTest
//
//  Created by PA on 15/2/2.
//
//

#import <Foundation/Foundation.h>

static NSString *const AdrXMLDictionaryAttributesKey   = @"__attributes";
static NSString *const AdrXMLDictionaryCommentsKey     = @"__comments";
static NSString *const AdrXMLDictionaryTextKey         = @"__text";
static NSString *const AdrXMLDictionaryNodeNameKey     = @"__name";
static NSString *const AdrXMLDictionaryAttributePrefix = @"_";

typedef NS_ENUM(NSInteger, AdrXMLDictionaryAttributesMode)
{
    AdrXMLDictionaryAttributesModePrefixed = 0, //default
    AdrXMLDictionaryAttributesModeDictionary,
    AdrXMLDictionaryAttributesModeUnprefixed,
    AdrXMLDictionaryAttributesModeDiscard
};

typedef NS_ENUM(NSInteger, AdrXMLDictionaryNodeNameMode)
{
    AdrXMLDictionaryNodeNameModeRootOnly = 0, //default
    AdrXMLDictionaryNodeNameModeAlways,
    AdrXMLDictionaryNodeNameModeNever
};

@interface AdrXMLToDictionaryParser : NSObject <NSCopying>

+ (AdrXMLToDictionaryParser *)sharedInstance;

@property (nonatomic, assign) BOOL collapseTextNodes; // defaults to YES
@property (nonatomic, assign) BOOL stripEmptyNodes;   // defaults to YES
@property (nonatomic, assign) BOOL trimWhiteSpace;    // defaults to YES
@property (nonatomic, assign) BOOL alwaysUseArrays;   // defaults to NO
@property (nonatomic, assign) BOOL preserveComments;  // defaults to NO
@property (nonatomic, assign) BOOL wrapRootNode;      // defaults to NO

@property (nonatomic, assign) AdrXMLDictionaryAttributesMode attributesMode;
@property (nonatomic, assign) AdrXMLDictionaryNodeNameMode nodeNameMode;

- (NSDictionary *)getDictionaryWithXMLParser:(NSXMLParser *)parser;
- (NSDictionary *)getDictionaryFromXMLData:(NSData *)data;
- (NSDictionary *)getDictionaryFromXMLString:(NSString *)string;

@end
