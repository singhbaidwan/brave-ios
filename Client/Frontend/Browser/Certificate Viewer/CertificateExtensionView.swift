// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import BraveRewards

extension BraveKeyUsage: Hashable { }

struct BraveCertificateExtensionKeyValueModel {
    let key: String
    let value: String
}

struct BraveCertificateKeyValueExtensionModel {
    let extensionType: BraveGenericExtensionType
    let singleValue: String?
    let multiValuePairs: [BraveCertificateExtensionKeyValueModel]? // Ordered Pairs
}

struct BraveCertificateSimplifiedExtensionModel {
    let type: BraveExtensionType
    let isCritical: Bool
    let onid: String
    let nid: Int
    let name: String
    let title: String
    
    let extensionInfo: BraveCertificateKeyValueExtensionModel
    
    init(genericModel: BraveCertificateGenericExtensionModel) {
        type = genericModel.type
        isCritical = genericModel.isCritical
        onid = genericModel.onid
        nid = genericModel.nid
        name = genericModel.name
        title = genericModel.title
        
        extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: genericModel.extensionType,
                                                               singleValue: genericModel.stringValue,
                                                               multiValuePairs: genericModel.arrayValue?.map({
                                                                BraveCertificateExtensionKeyValueModel(key: $0.key, value: $0.value)
                                                               })
        )
    }
    
    init(genericModel: BraveCertificateExtensionModel, extensionInfo: BraveCertificateKeyValueExtensionModel) {
        type = genericModel.type
        isCritical = genericModel.isCritical
        onid = genericModel.onid
        nid = genericModel.nid
        name = genericModel.name
        title = genericModel.title
        self.extensionInfo = extensionInfo
    }
}

extension BraveCertificateBasicConstraintsExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)"),
                                                                    BraveCertificateExtensionKeyValueModel(key: "IsCA", value: "\(isCA)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateKeyUsageExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let mapping: [BraveKeyUsage: String] = [
            .INVALID: "Invalid",
            .DIGITAL_SIGNATURE: "Digital Signature",
            .NON_REPUDIATION: "Non-Repudiation",
            .KEY_ENCIPHERMENT: "Key Encipherment",
            .DATA_ENCIPHERMENT: "Data Encipherment",
            .KEY_AGREEMENT: "Key Agreement",
            .KEY_CERT_SIGN: "Key Certificate Signing",
            .CRL_SIGN: "CRL Signing",
            .ENCIPHER_ONLY: "Enciphering Only",
            .DECIPHER_ONLY: "Deciphering Only"
        ]
        
        let keyUsages = mapping.compactMap({
            self.keyUsage.contains($0.key) ? $0.value : nil
        }).joined(separator: ", ")
        
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)"),
                                                                    BraveCertificateExtensionKeyValueModel(key: "Key Usage", value: keyUsages)
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateExtendedKeyUsageExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
        ] + keyPurposes.enumerated().map({
            BraveCertificateExtensionKeyValueModel(key: "Purpose #\($0.offset + 1)", value: "\($0.element.name) (\($0.element.nidString)")
        })
        
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: extensionValues)
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateSubjectKeyIdentifierExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)"),
                                                                    BraveCertificateExtensionKeyValueModel(key: "Key ID", value: hexEncodedkeyInfo)
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateAuthorityKeyIdentifierExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificatePrivateKeyUsagePeriodExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateSubjectAlternativeNameExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateIssuerAlternativeNameExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateAuthorityInformationAccessExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateSubjectInformationAccessExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateNameConstraintsExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificatePoliciesExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificatePolicyMappingsExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificatePolicyConstraintsExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateInhibitAnyPolicyExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateTLSFeatureExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}
    
// Netscape Certificate Extensions - Largely Obsolete
extension BraveCertificateNetscapeCertTypeExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateNetscapeURLExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateNetscapeStringExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

    
// Miscellaneous Certificate Extensions
extension BraveCertificateSXNetExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}
extension BraveCertificateProxyCertInfoExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

    
// PKIX CRL Extensions
extension BraveCertificateCRLNumberExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateCRLDistributionPointsExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateDeltaCRLExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateInvalidityDateExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateIssuingDistributionPointExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

    
// CRL entry extensions from PKIX standards such as RFC5280
extension BraveCertificateCRLReasonExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateIssuerExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

    
// OCSP Extensions
extension BraveCertificatePKIXOCSPNonceExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateSCTExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}

extension BraveCertificateGenericExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionInfo = BraveCertificateKeyValueExtensionModel(extensionType: .KEY_VALUE,
                                                                   singleValue: nil,
                                                                   multiValuePairs: [
                                                                    BraveCertificateExtensionKeyValueModel(key: "Critical", value: "\(isCritical)")
                                                                   ])
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: extensionInfo)
    }
}
