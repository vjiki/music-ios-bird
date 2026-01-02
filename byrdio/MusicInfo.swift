//
//  MusicInfo.swift
//  music
//
//  Created by Nikolai Golubkin on 15. 8. 2025..
//

import SwiftUI

struct MusicInfo: View {
    // Animation properties
    @Binding var expandSheet: Bool
    var animation: Namespace.ID
    
    @EnvironmentObject var songManager: SongManager
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if !expandSheet {
                    GeometryReader {
                        let size = $0.size

                        CachedAsyncImage(url: URL(string: songManager.song.cover)) { img in
                            img.resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                                .background(.white.opacity(0.1))
                                .clipShape(.rect(cornerRadius: 5))
                        }
                            .frame(width: size.width, height: size.height)
                            .clipShape(.rect(cornerRadius: 60, style: .continuous))
                        
                        
                        CircleProgressView(progress: songManager.progress)
                            .frame(width: size.width, height: size.height)
                    }
                    .matchedGeometryEffect(id: "SONGCOVER", in: animation)
                }
            }
            .frame(width: 55, height: 55)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(songManager.song.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(songManager.song.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .padding(.horizontal, 15)
            
            Spacer()
            
            Button {
                songManager.togglePlayPause()
            } label: {
                Image(systemName: songManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.black)
                    .padding()
                    .background(.white)
                    .clipShape(Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .frame(height: 80)
//        .contentShape(.rect(topLeadingRadius: 30, topTrailingRadius: 30))
        .onTapGesture {
            //
            withAnimation(.easeInOut(duration: 0.3)) {
                expandSheet = true
            }
        }

    }
}

#Preview {
    Home()
        .preferredColorScheme(.dark)
}


struct CircleProgressView: View {
    
    let progress: Double
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2),
                        lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.blue,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
