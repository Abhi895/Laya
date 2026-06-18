//
//  ContentView.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

//#Preview {
//    ContentView()
//}

#Preview {
    // If this compiles and shows the data, your mock stack is wired correctly
    VStack {
        Text(Artist.mock.name)
        Text(Journey.mock.chapters[0].title)
    }
}
