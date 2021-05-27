// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import BraveRewards
import SwiftUI
import BraveUI

class BraveCertificate: ObservableObject {
    @Published var value: BraveCertificateModel
    
    init(model: BraveCertificateModel) {
        self.value = model
    }
    
    init?(name: String) {
        if let data = BraveCertificate.loadCertificateData(name: name),
           let model = BraveCertificateModel(data: data as Data) {
            self.value = model
            return
        }
        return nil
    }
    
    init?(certificate: SecCertificate) {
        if let model = BraveCertificateModel(certificate: certificate) {
            self.value = model
            return
        }
        return nil
    }
    
    init?(data: Data) {
        if let model = BraveCertificateModel(data: data) {
            self.value = model
            return
        }
        return nil
    }
    
    private static func loadCertificateData(name: String) -> CFData? {
        guard let path = Bundle.main.path(forResource: name, ofType: "cer") else {
            return nil
        }
        
        guard let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData else {
            return nil
        }
        return certificateData
    }
    
    private static func loadCertificate(name: String) -> SecCertificate? {
        guard let certificateData = loadCertificateData(name: name) else {
            return nil
        }
        return SecCertificateCreateWithData(nil, certificateData)
    }
}

struct CertificateTitleView: View {
    let isRootCertificate: Bool
    let commonName: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 15.0) {
            Image(uiImage: isRootCertificate ? #imageLiteral(resourceName: "Root") : #imageLiteral(resourceName: "Other"))
            VStack(alignment: .leading, spacing: 10.0) {
                Text(commonName)
                    .font(.system(size: 16.0, weight: .bold))
            }
        }
    }
}

struct CertificateTitleValueView: View, Hashable {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12.0) {
            Text(title)
                .font(.system(size: 12.0))
                .foregroundColor(.black)
            Spacer(minLength: 20.0)
            Text(value)
                .lineLimit(nil)
                .font(.system(size: 12.0, weight: .medium))
                .foregroundColor(.black)
        }
    }
}

struct CertificateSectionView<ContentView>: View where ContentView: View {
    let title: String
    let values: [ContentView]
    
    var body: some View {
        Text(title)
            .font(.system(size: 12.0))
            .foregroundColor(Color(#colorLiteral(red: 0.4988772273, green: 0.4988895059, blue: 0.4988829494, alpha: 1)))
        
        VStack(alignment: .leading, spacing: 0.0) {
            ForEach(values.indices, id: \.self) {
                values[$0].padding(EdgeInsets(top: 10.0,
                                      leading: 0.0,
                                      bottom: 10.0,
                                      trailing: 10.0))
                
                if $0 != values.count - 1 {
                    Divider()
                }
            }
        }.padding(.leading, 10).background(Color(#colorLiteral(red: 0.9725490196, green: 0.9764705882, blue: 0.9843137255, alpha: 1))).cornerRadius(5.0)
    }
}

struct CertificateView: View {
    @EnvironmentObject var model: BraveCertificate
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 5.0) {
                CertificateTitleView(isRootCertificate:
                                        model.value.isRootCertificate,
                                     commonName: model.value.subjectName.commonName)
                Spacer(minLength: 20.0)
                VStack(alignment: .leading, spacing: 10.0) {
                    // Subject name
                    CertificateSectionView(title: "Subject Name", values: subjectNameViews())
                    
                    // Issuer name
                    CertificateSectionView(title: "Issuer Name",
                                           values: issuerNameViews())
                    
                    // Common info
                    CertificateSectionView(title: "Common Info",
                                           values: [
                      // Serial number
                      CertificateTitleValueView(title: "Serial Number",
                                                value: formattedSerialNumber()),
                                            
                      // Version
                      CertificateTitleValueView(title: "Version",
                                                value: "\(model.value.version)"),
                                            
                      // Signature Algorithm
                      CertificateTitleValueView(title: "Signature Algorithm",
                                                value: "\(model.value.signature.algorithm) (\(model.value.signature.objectIdentifier))"),
                      //signatureParametersView().padding(.leading, 18.0)
                    ])
                    
                    // Validity info
                    CertificateSectionView(title: "Validity Dates",
                                           values: [
                      // Not Valid Before
                      CertificateTitleValueView(title: "Not Valid Before",
                                                value: formatDate(model.value.notValidBefore)),
                    
                      // Not Valid After
                      CertificateTitleValueView(title: "Not Valid After",
                                                value: formatDate(model.value.notValidAfter))
                    ])
                    
                    // Public Key Info
                    CertificateSectionView(title: "Public Key info",
                                           values: publicKeyInfoViews())
                    
                    // Signature
                    CertificateSectionView(title: "Signature",
                                           values: [
                      CertificateTitleValueView(title: "Signature",
                                                value: formattedSignature())
                    ])
                    
                    // Fingerprints
                    CertificateSectionView(title: "Fingerprints",
                                           values: fingerprintViews())
                }
                Spacer(minLength: 10.0)
                VStack(alignment: .leading, spacing: 10.0) {
                    ForEach(extensionViews().indices, id: \.self) {
                        extensionViews()[$0]
                    }
                }
            }.padding()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity)
        .environmentObject(model)
    }
}

extension CertificateView {
    private func subjectNameViews() -> [CertificateTitleValueView] {
        let subjectName = model.value.subjectName
        
        // Ordered mapping
        let mapping = [
            KeyValue(key: "Country or Region", value: subjectName.countryOrRegion),
            KeyValue(key: "State/Province", value: subjectName.stateOrProvince),
            KeyValue(key: "Locality", value: subjectName.locality),
            KeyValue(key: "Organization", value: subjectName.organization),
            KeyValue(key: "Organizational Unit", value: subjectName.organizationalUnit),
            KeyValue(key: "Common Name", value: subjectName.commonName),
            KeyValue(key: "Street Address", value: subjectName.streetAddress),
            KeyValue(key: "Domain Component", value: subjectName.domainComponent),
            KeyValue(key: "User ID", value: subjectName.userId)
        ]
        
        return mapping.compactMap({
            $0.value.isEmpty ? nil : CertificateTitleValueView(title: $0.key,
                                                               value: $0.value)
        })
    }
    
    private func issuerNameViews() -> [CertificateTitleValueView] {
        let issuerName = model.value.issuerName
        
        // Ordered mapping
        let mapping = [
            KeyValue(key: "Country or Region", value: issuerName.countryOrRegion),
            KeyValue(key: "State/Province", value: issuerName.stateOrProvince),
            KeyValue(key: "Locality", value: issuerName.locality),
            KeyValue(key: "Organization", value: issuerName.organization),
            KeyValue(key: "Organizational Unit", value: issuerName.organizationalUnit),
            KeyValue(key: "Common Name", value: issuerName.commonName),
            KeyValue(key: "Street Address", value: issuerName.streetAddress),
            KeyValue(key: "Domain Component", value: issuerName.domainComponent),
            KeyValue(key: "User ID", value: issuerName.userId)
        ]
        
        return mapping.compactMap({
            $0.value.isEmpty ? nil : CertificateTitleValueView(title: $0.key,
                                                               value: $0.value)
        })
    }
    
    private func formattedSerialNumber() -> String {
        let serialNumber = model.value.serialNumber
        if Int64(serialNumber) != nil || UInt64(serialNumber) != nil {
            return "\(serialNumber)"
        }
        return formatHex(model.value.serialNumber)
    }
    
    private func signatureParametersView() -> CertificateTitleValueView {
        let signature = model.value.signature
        let parameters = signature.parameters.isEmpty ? "None" : formatHex(signature.parameters)
        return CertificateTitleValueView(title: "Parameters",
                                         value: parameters)
    }
    
    private func publicKeyInfoViews() -> [CertificateTitleValueView] {
        let publicKeyInfo = model.value.publicKeyInfo
        
        var algorithm = publicKeyInfo.algorithm
        if !publicKeyInfo.curveName.isEmpty {
            algorithm += " - \(publicKeyInfo.curveName)"
        }
        
        if !algorithm.isEmpty {
            algorithm += " (\(publicKeyInfo.objectIdentifier))"
        }
        
        let parameters = publicKeyInfo.parameters.isEmpty ? "None" : "\(publicKeyInfo.parameters.count / 2) bytes : \(formatHex(publicKeyInfo.parameters))"
        
        // TODO: Number Formatter
        let publicKey = "\(publicKeyInfo.keyBytesSize) bytes : \(formatHex(publicKeyInfo.keyHexEncoded))"
        
        // TODO: Number Formatter
        let keySizeInBits = "\(publicKeyInfo.keySizeInBits) bits"
        
        var keyUsages = [String]()
        if publicKeyInfo.keyUsage.contains(.DATA_ENCIPHERMENT) ||
            (publicKeyInfo.keyUsage.contains(.KEY_AGREEMENT) && publicKeyInfo.keyUsage.contains(.KEY_ENCIPHERMENT)) {
            keyUsages.append("Encrypt")
        }
        
        if publicKeyInfo.keyUsage.contains(.DIGITAL_SIGNATURE) {
            keyUsages.append("Verify")
        }
        
        if publicKeyInfo.keyUsage.contains(.KEY_ENCIPHERMENT) {
            keyUsages.append("Wrap")
        }
        
        if publicKeyInfo.keyUsage.contains(.KEY_AGREEMENT) {
            keyUsages.append("Derive")
        }
        
        if publicKeyInfo.type == .RSA && (publicKeyInfo.keyUsage.isEmpty || publicKeyInfo.keyUsage.rawValue == BraveKeyUsage.INVALID.rawValue) {
            keyUsages.append("Encrypt")
            keyUsages.append("Verify")
            keyUsages.append("Derive")
        } else if publicKeyInfo.keyUsage.isEmpty || publicKeyInfo.keyUsage.rawValue == BraveKeyUsage.INVALID.rawValue {
            keyUsages.append("Any")
        }
        
        let exponent = publicKeyInfo.exponent != 0 ? "\(publicKeyInfo.exponent)" : ""
        
        // Ordered mapping
        let mapping = [
            KeyValue(key: "Algorithm", value: algorithm),
            KeyValue(key: "Parameters", value: parameters),
            KeyValue(key: "Public Key", value: publicKey),
            KeyValue(key: "Exponent", value: exponent),
            KeyValue(key: "Key Size", value: keySizeInBits),
            KeyValue(key: "Key Usage", value: keyUsages.joined(separator: " "))
        ]
        
        return mapping.compactMap({
            $0.value.isEmpty ? nil : CertificateTitleValueView(title: $0.key,
                                                               value: $0.value)
        })
    }
    
    private func formattedSignature() -> String {
        let signature = model.value.signature
        return "\(signature.bytesSize) bytes : \(formatHex(signature.signatureHexEncoded))"
    }
    
    private func extensionViews() -> [CertificateSectionView<CertificateTitleValueView>] {
        let extensions = model.value.extensions
        
        var result = [CertificateSectionView<CertificateTitleValueView>]()
        for certExtension in extensions {
            if certExtension.nid <= 0 { // NID_undef
                let view = CertificateSectionView(title: "Extension Unknown (\(certExtension.onid))", values: [
                    
                    CertificateTitleValueView(title: "Critical", value: certExtension.isCritical ? "YES" : "NO")
                ])
                result.append(view)
            } else {
                
            }
        }
        return result
    }
    
    private func extensionView(from extensionType: BraveExtensionType,
                               certExtension: BraveCertificateExtensionModel) -> AnyView? {
        switch extensionType {
        case .UNKNOWN:
            guard let model = certExtension as? BraveCertificateGenericExtensionModel else {
                return nil
            }

            break
            
        // PKIX Certificate Extensions
        case .BASIC_CONSTRAINTS:
            guard let model = certExtension as? BraveCertificateBasicConstraintsExtensionModel else {
                return nil
            }

            break
        case .KEY_USAGE:
            guard let model = certExtension as? BraveCertificateKeyUsageExtensionModel else {
                return nil
            }

            break
        case .EXT_KEY_USAGE:
            guard let model = certExtension as? BraveCertificateExtendedKeyUsageExtensionModel else {
                return nil
            }

            break
        case .SUBJECT_KEY_IDENTIFIER:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .AUTHORITY_KEY_IDENTIFIER:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .PRIVATE_KEY_USAGE_PERIOD:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .SUBJECT_ALT_NAME:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .ISSUER_ALT_NAME:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .INFO_ACCESS:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .SINFO_ACCESS:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .NAME_CONSTRAINTS:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .CERTIFICATE_POLICIES:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .POLICY_MAPPINGS:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .POLICY_CONSTRAINTS:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .INHIBIT_ANY_POLICY:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .TLSFEATURE:
            guard let model = certExtension as? Any else {
                return nil
            }

            break

        // Netscape Certificate Extensions - Largely Obsolete
        case .NETSCAPE_CERT_TYPE:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .NETSCAPE_BASE_URL:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .NETSCAPE_REVOCATION_URL:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .NETSCAPE_CA_REVOCATION_URL:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .NETSCAPE_RENEWAL_URL:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .NETSCAPE_CA_POLICY_URL:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .NETSCAPE_SSL_SERVER_NAME:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .NETSCAPE_COMMENT:
            guard let model = certExtension as? Any else {
                return nil
            }

            break

        // Miscellaneous Certificate Extensions
        case .SXNET:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .PROXYCERTINFO:
            guard let model = certExtension as? Any else {
                return nil
            }

            break

        // PKIX CRL Extensions
        case .CRL_NUMBER:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .CRL_DISTRIBUTION_POINTS:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .DELTA_CRL:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .FRESHEST_CRL:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .INVALIDITY_DATE:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .ISSUING_DISTRIBUTION_POINT:
            guard let model = certExtension as? Any else {
                return nil
            }

            break

        // CRL entry extensions from PKIX standards such as RFC5280
        case .CRL_REASON:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .CERTIFICATE_ISSUER:
            guard let model = certExtension as? Any else {
                return nil
            }

            break

        // OCSP Extensions
        case .ID_PKIX_OCSP_NONCE:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .ID_PKIX_OCSP_CRLID:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .ID_PKIX_OCSP_ACCEPTABLERESPONSES:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .ID_PKIX_OCSP_NOCHECK:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .ID_PKIX_OCSP_ARCHIVECUTOFF:
             guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .ID_PKIX_OCSP_SERVICELOCATOR:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .HOLD_INSTRUCTION_CODE:
            guard let model = certExtension as? Any else {
                return nil
            }

            break

        // Certificate Transparency Extensions
        case .CT_PRECERT_SCTS:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
        case .CT_CERT_SCTS:
            guard let model = certExtension as? Any else {
                return nil
            }

            break
            
        @unknown default:
            fatalError()
        }
        return nil
    }
    
    private func fingerprintViews() -> [CertificateTitleValueView] {
        let sha256Fingerprint = model.value.sha256Fingerprint
        let sha1Fingerprint = model.value.sha1Fingerprint
        
        return [
            CertificateTitleValueView(title: "SHA-256", value: formatHex(sha256Fingerprint.fingerprintHexEncoded)),
            CertificateTitleValueView(title: "SHA-1", value: formatHex(sha1Fingerprint.fingerprintHexEncoded))
        ]
    }
    
    private func formatHex(_ hexString: String, separator: String = " ") -> String {
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
    
    private func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter().then {
            $0.dateStyle = .full
            $0.timeStyle = .full
        }
        return dateFormatter.string(from: date)
    }
    
    private struct KeyValue {
        let key: String
        let value: String
    }
}

struct CertificateView_Previews: PreviewProvider {
    static var previews: some View {
        let model = BraveCertificate(name: "leaf")!

        CertificateView()
            .environmentObject(model)
    }
}

class CertificateViewController: UIViewController, PopoverContentComponent {
    
    init(certificate: BraveCertificate) {
        super.init(nibName: nil, bundle: nil)
        
        let rootView = CertificateView().environmentObject(certificate)
        let controller = UIHostingController(rootView: rootView)
        
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        
        controller.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
