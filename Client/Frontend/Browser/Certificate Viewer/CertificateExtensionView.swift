// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import BraveRewards
import SwiftUI

struct BraveCertificateExtensionView: View {
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

struct BraveCertificateExtensionMultiValueView: View {
    let title: String
    let value: String
    
    let subTitle: String?
    let subValue: String?
    
    init(title: String, value: String, subTitle: String? = nil, subValue: String? = nil) {
        self.title = title
        self.value = value
        self.subTitle = subTitle
        self.subValue = subValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            BraveCertificateExtensionView(title: title, value: value)
            
            if let subTitle = subTitle, let subValue = subValue {
                BraveCertificateExtensionView(title: subTitle, value: subValue).padding(.leading, 20)
            } else if let title = subTitle ?? subValue {
                BraveCertificateExtensionView(title: title, value: "").padding(.leading, 20)
            }
        }
    }
}

struct BraveCertificateExtensionView_Previews: PreviewProvider {
    static var previews: some View {
        let model = BraveCertificate(name: "leaf")!

        BraveCertificateExtensionMultiValueView(title: "Key",
                                                value: "Value",
                                                subTitle: "Test")
    }
}

extension BraveCertificateGenericExtensionModel {
    
}
