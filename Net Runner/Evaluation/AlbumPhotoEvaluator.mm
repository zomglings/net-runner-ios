//
//  AlbumPhotoEvaluator.mm
//  Net Runner
//
//  Created by Philip Dow on 7/18/18.
//  Copyright © 2018 doc.ai (http://doc.ai)
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "AlbumPhotoEvaluator.h"

#import "EvaluatorConstants.h"
#import "ImageEvaluator.h"
#import "Utilities.h"

@import TensorIO;

@interface AlbumPhotoEvaluator()

+ (PHImageRequestOptions*) imageRequestOptions;

@property (readwrite) NSDictionary *results;
@property (readwrite) id<TIOModel> model;

@end

@implementation AlbumPhotoEvaluator {
    dispatch_once_t _once;
}

+ (PHImageRequestOptions*)imageRequestOptions {
    static PHImageRequestOptions *options = nil;
    
    if ( options != nil ) {
        return options;
    }
    
    options = [[PHImageRequestOptions alloc] init];
    
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    options.networkAccessAllowed = YES;
    options.synchronous = YES;
    
    return options;
}

- (instancetype)initWithModel:(id<TIOModel>)model photo:(PHAsset*)photo album:(PHAssetCollection*)album imageManager:(PHCachingImageManager*)imageManager {
    if (self = [super init]) {
        _model = model;
        _photo = photo;
        _album = album;
        _imageManager = imageManager;
    }
    
    return self;
}

- (void)evaluateWithCompletionHandler:(nullable EvaluatorCompletionBlock)completionHandler {
    dispatch_once(&_once, ^{

    [self.imageManager
        requestImageForAsset:self.photo
        targetSize:PHImageManagerMaximumSize
        contentMode:PHImageContentModeAspectFill
        options:[AlbumPhotoEvaluator imageRequestOptions]
        resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        
        @autoreleasepool {
        
            tio_defer_block {
                self.model = nil;
            };
        
            if ( result == nil ) {
                NSString *errorDescription = [NSString stringWithFormat:@"Unable to request image for asset %@",  self.photo.localIdentifier];
                NSLog(@"%@", errorDescription);
                NSDictionary *evaluatorResults = @{
                    kEvaluatorResultsKeySourceType          : kEvaluatorResultsKeySourceTypeAlbumPhoto,
                    kEvaluatorResultsKeyAlbum               : self.album.localIdentifier,
                    kEvaluatorResultsKeyImage               : self.photo.localIdentifier,
                    kEvaluatorResultsKeyModel               : self.model.identifier,
                    kEvaluatorResultsKeyError               : @(YES),
                    kEvaluatorResultsKeyErrorDescription    : errorDescription,
                    kEvaluatorResultsKeyEvaluation          : [NSNull null]
                };
                safe_block(completionHandler, evaluatorResults, NULL);
                return;
            }
            
            ImageEvaluator *imageEvaluator = [[ImageEvaluator alloc] initWithModel:self.model image:result];
            
            [imageEvaluator evaluateWithCompletionHandler:^(NSDictionary *results, CVPixelBufferRef _Nullable inputPixelBuffer) {
                NSDictionary *evaluatorResults = @{
                    kEvaluatorResultsKeySourceType          : kEvaluatorResultsKeySourceTypeAlbumPhoto,
                    kEvaluatorResultsKeyAlbum               : self.album.localIdentifier,
                    kEvaluatorResultsKeyImage               : self.photo.localIdentifier,
                    kEvaluatorResultsKeyModel               : self.model.identifier,
                    kEvaluatorResultsKeyError               : @(NO),
                    kEvaluatorResultsKeyEvaluation          : results
                };
                safe_block(completionHandler, evaluatorResults, inputPixelBuffer);
            }];
        }
    }];
    
    }); // dispatch_once
}

@end
