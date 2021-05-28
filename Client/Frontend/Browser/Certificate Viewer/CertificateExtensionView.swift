// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import BraveRewards

extension BraveKeyUsage: Hashable { }
extension BraveNetscapeCertificateType: Hashable {}

struct BraveCertificateUtilities {
    static func formatHex(_ hexString: String, separator: String = " ") -> String {
        let n = 2
        let characters = Array(hexString)
        
        var result: String = ""
        stride(from: 0, to: characters.count, by: n).forEach {
            result += String(characters[$0..<min($0 + n, characters.count)])
            if $0 + n < characters.count {
                result += separator
            }
        }
        return result
    }
    
    static func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter().then {
            $0.dateStyle = .full
            $0.timeStyle = .full
        }
        return dateFormatter.string(from: date)
    }
    
    static func generalNameToExtensionValueType(_ generalName: BraveCertificateExtensionGeneralNameModel) -> BraveCertificateExtensionKeyValueType {
        switch generalName.type {
        case .INVALID:
            return .keyValue("Invalid", .string(generalName.other))
        case .OTHER_NAME:
            return .keyValue("Other Name", .string(generalName.other))
        case .EMAIL:
            return .keyValue("Email", .string(generalName.other))
        case .DNS:
            return .keyValue("DNS", .string(generalName.other))
        case .X400:
            return .keyValue("X400", .string(generalName.other))
        case .DIRNAME:
            return .keyValue("Directory Name", .nested(generalName.dirName.map {
                .keyValue($0.key, .string($0.value))
            }))
        case .EDIPARTY:
            return .keyValue("Electronic Data Interchange", .nested([
                .keyValue("Name Assigner", .string(generalName.nameAssigner)),
                .keyValue("Party Name", .string(generalName.partyName))
            ]))
        case .URI:
            return .keyValue("URI", .string(generalName.other))
        case .IPADD:
            return .keyValue("IP Address", .string(generalName.other))
        case .RID:
            return .keyValue("Registered ID", .string(generalName.other))
            
        @unknown default:
            fatalError()
            break
        }
    }
}

indirect enum BraveCertificateExtensionKeyValueType {
    case string(String)
    case boolean(Bool)
    case hexString(String)
    case keyValue(String, BraveCertificateExtensionKeyValueType)
    case nested([BraveCertificateExtensionKeyValueType])
}

struct BraveCertificateExtensionKeyValueModel {
    let key: String
    let value: BraveCertificateExtensionKeyValueType
}

enum BraveCertificateSimpleExtensionValue {
    case string(String)
    case hexString(String)
    case keyValue([BraveCertificateExtensionKeyValueModel])
}

struct BraveCertificateSimplifiedExtensionModel {
    let type: BraveExtensionType
    let isCritical: Bool
    let onid: String
    let nid: Int
    let name: String
    let title: String
    
    let extensionInfo: BraveCertificateSimpleExtensionValue
    
    init(genericModel: BraveCertificateGenericExtensionModel) {
        type = genericModel.type
        isCritical = genericModel.isCritical
        onid = genericModel.onid
        nid = genericModel.nid
        name = genericModel.name
        title = genericModel.title
        
        switch genericModel.extensionType {
        case .STRING:
            extensionInfo = .string(genericModel.stringValue ?? "")
        case .HEX_STRING:
            extensionInfo = .hexString(BraveCertificateUtilities.formatHex(genericModel.stringValue ?? ""))
        case .KEY_VALUE:
            extensionInfo = .keyValue(genericModel.arrayValue?.map({
                BraveCertificateExtensionKeyValueModel(key: $0.key, value: .string($0.value))
            }) ?? [])
        @unknown default:
            fatalError()
        }
    }
    
    init(genericModel: BraveCertificateExtensionModel, extensionInfo: BraveCertificateSimpleExtensionValue) {
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
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "IsCA", value: .boolean(isCA))
        ]
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
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
            keyUsage.contains($0.key) ? $0.value : nil
        }).joined(separator: ", ")
        
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "Key Usage", value: .string(keyUsages))
        ]
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateExtendedKeyUsageExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical))
        ] + keyPurposes.enumerated().map({
            BraveCertificateExtensionKeyValueModel(key: "Purpose #\($0.offset + 1)",
                                                   value: .string("\($0.element.name) (\($0.element.nidString)"))
        })
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateSubjectKeyIdentifierExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "Key ID", value: .hexString(
                                                    BraveCertificateUtilities.formatHex(hexEncodedkeyInfo))
            )
        ]
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateAuthorityKeyIdentifierExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "Key ID", value: .hexString(
                                                    BraveCertificateUtilities.formatHex(keyId))
            )
        ]
        
        if !serial.isEmpty {
            extensionValues.append(BraveCertificateExtensionKeyValueModel(key: "Serial Number",
                                                                          value: .hexString(
                                                                            BraveCertificateUtilities.formatHex(serial)
                                                                          ))
            )
        }
        
        if !issuer.isEmpty {
            let issuerInfo = issuer.map({
                BraveCertificateUtilities.generalNameToExtensionValueType($0)
            })
            
            extensionValues.append(BraveCertificateExtensionKeyValueModel(key: "Issuer", value: .nested(issuerInfo)))
        }
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificatePrivateKeyUsagePeriodExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionInfo = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical))
        ]
        
        if let notBefore = notBefore {
            extensionInfo.append(BraveCertificateExtensionKeyValueModel(key: "Not Before",
                                                                        value: .string(
                                                                            BraveCertificateUtilities.formatDate(notBefore)))
            )
        }
        
        if let notAfter = notAfter {
            extensionInfo.append(BraveCertificateExtensionKeyValueModel(key: "Not After",
                                                                        value: .string(
                                                                            BraveCertificateUtilities.formatDate(notAfter)))
            )
        }
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionInfo))
    }
}

extension BraveCertificateSubjectAlternativeNameExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical))
        ]
        
        let names = names.map({
            BraveCertificateUtilities.generalNameToExtensionValueType($0)
        })
        
        extensionValues.append(BraveCertificateExtensionKeyValueModel(key: "Names", value: .nested(names)))
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateIssuerAlternativeNameExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical))
        ]
        
        let names = names.map({
            BraveCertificateUtilities.generalNameToExtensionValueType($0)
        })
        
        extensionValues.append(BraveCertificateExtensionKeyValueModel(key: "Names", value: .nested(names)))
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateAuthorityInformationAccessExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
        ]
        
        let accessDescriptions = accessDescriptions.map({
            BraveCertificateExtensionKeyValueModel(key: "\($0.oidName) \($0.oid)",
                                                   value: .nested($0.locations.map({ BraveCertificateUtilities.generalNameToExtensionValueType($0)
                                                   })
            ))
        })
        
        extensionValues.append(contentsOf: accessDescriptions)
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateSubjectInformationAccessExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
        ]
        
        let accessDescriptions = accessDescriptions.map({
            BraveCertificateExtensionKeyValueModel(key: "\($0.oidName) \($0.oid)",
                                                   value: .nested($0.locations.map({ BraveCertificateUtilities.generalNameToExtensionValueType($0)
                                                   })
            ))
        })
        
        extensionValues.append(contentsOf: accessDescriptions)
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateNameConstraintsExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
        ]
        
        if !permittedSubtrees.isEmpty {
            let permittedSubtrees = permittedSubtrees.enumerated().map({
                BraveCertificateExtensionKeyValueType.keyValue("Tree #\($0.offset)", .nested([
                    .keyValue("Minimum", .string($0.element.minimum)),
                    .keyValue("Maximum", .string($0.element.maximum)),
                    .keyValue("Names", .nested($0.element.names.map {
                        BraveCertificateUtilities.generalNameToExtensionValueType($0)
                    })),
                ]))
            })
            
            extensionValues.append(BraveCertificateExtensionKeyValueModel(key: "Permitted", value: .nested(permittedSubtrees)))
        }
        
        if !excludedSubtrees.isEmpty {
            let excludedSubtrees = excludedSubtrees.enumerated().map({
                BraveCertificateExtensionKeyValueType.keyValue("Tree #\($0.offset)", .nested([
                    .keyValue("Minimum", .string($0.element.minimum)),
                    .keyValue("Maximum", .string($0.element.maximum)),
                    .keyValue("Names", .nested($0.element.names.map {
                        BraveCertificateUtilities.generalNameToExtensionValueType($0)
                    })),
                ]))
            })
            
            extensionValues.append(BraveCertificateExtensionKeyValueModel(key: "Excluded", value: .nested(excludedSubtrees)))
        }
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificatePoliciesExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
        ]
        
        let policies = policies.enumerated().map({
            BraveCertificateExtensionKeyValueModel(key: "Policy #\($0.offset) (\($0.element.oid))", value: .nested($0.element.qualifiers.map {
                .keyValue("Qualifier ID #\($0.pqualId)", .nested([
                    .keyValue("CPS", .string($0.cps)),
                    .keyValue("Notice", .nested([
                        .keyValue("Organization", .string($0.notice?.organization ?? "")),
                        .keyValue("Notice Numbers", .string($0.notice?.noticeNumbers.joined(separator: ", ") ?? "")),
                        .keyValue("Explicit Text", .string($0.notice?.explicitText ?? ""))
                    ]))
                ]))
            }))
        })
        
        extensionValues.append(contentsOf: policies)
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificatePolicyMappingsExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        var extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
        ]
        
        let policies = policies.enumerated().map({
            BraveCertificateExtensionKeyValueModel(key: "Policy #\($0.offset)", value: .nested([
                .keyValue("Subject Domain", .string($0.element.subjectDomainPolicy)),
                .keyValue("Issuer Domain", .string($0.element.issuerDomainPolicy))
            ]))
        })
        
        extensionValues.append(contentsOf: policies)
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificatePolicyConstraintsExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "Require Explicit Policy", value: .string(requireExplicitPolicy)),
            BraveCertificateExtensionKeyValueModel(key: "Inhibit Policy Mapping", value: .string(inhibitPolicyMapping))
        ]
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateInhibitAnyPolicyExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "Policy Any", value: .string(policyAny)),
        ]
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateTLSFeatureExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "Features", value: .string(
                features.map({ "v\($0.int64Value)" }).joined(separator: ", ")
            )),
        ]
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}
    
// Netscape Certificate Extensions - Largely Obsolete
extension BraveCertificateNetscapeCertTypeExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let mapping: [BraveNetscapeCertificateType: String] = [
            .INVALID: "Invalid",
            .SSL_CLIENT: "SSL Client",
            .SSL_SERVER: "SSL Server",
            .SMIME: "SMIME",
            .OBJSIGN: "Object Sign",
            .SSL_CA: "SSL CA",
            .SMIME_CA: "SMIME CA",
            .OBJSIGN_CA: "Object Sign CA",
            .ANY_CA: "Any CA"
        ]
        
        let certTypes = mapping.compactMap({
            certType.contains($0.key) ? $0.value : nil
        }).joined(separator: ", ")
        
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "Purposes", value: .string(certTypes))
        ]
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateNetscapeURLExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "URL", value: .string(url))
        ]
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

extension BraveCertificateNetscapeStringExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "String", value: .string(string))
        ]
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
    }
}

    
// Miscellaneous Certificate Extensions
/*extension BraveCertificateSXNetExtensionModel {
    func toKeyValuePairs() -> BraveCertificateSimplifiedExtensionModel {
        let extensionValues = [
            BraveCertificateExtensionKeyValueModel(key: "Critical", value: .boolean(isCritical)),
            BraveCertificateExtensionKeyValueModel(key: "Version", value: .string("\(version + 1)")),
            BraveCertificateExtensionKeyValueModel(key: "IDs", value: .nested(ids.enumerated().compactMap {
                [
                .keyValue("Zone #\($0.offset)", .string($0.element.zone())),
                .keyValue("User #\($0.offset)", .string($0.element.user)),
                    ]
            })),
        ]
        
        return BraveCertificateSimplifiedExtensionModel(genericModel: self, extensionInfo: .keyValue(extensionValues))
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
}*/
