//
//  MusicView.swift
//  music
//
//  Created by Nikolai Golubkin on 16. 8. 2025..
//

import SwiftUI

struct MusicView: View {
    
    @Binding var expandSheet: Bool
    var animation: Namespace.ID
    // View Properties
    @State private var animateContent: Bool = false
    @State private var offsetY: CGFloat = 0
    @State private var showArtistView = false
    
    // Optional story image URL (if opened from story)
    var storyImageURL: String? = nil
    
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            let safeArea = $0.safeAreaInsets
            
            ZStack(alignment: .top) {
                // Opaque black background
                Color.black
                    .ignoresSafeArea()
                
                RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                    .fill(.black)
                    .overlay {
                        Rectangle()
                            .fill(.black)
                            .opacity(animateContent ? 1 : 0)
                    }
                    .overlay(alignment: .top) {
                        MusicInfo(expandSheet: $expandSheet, animation: animation)
                            .allowsHitTesting(false)
                            .opacity(animateContent ? 0 : 1)
                    }
                    .matchedGeometryEffect(id: "BACKGROUNDVIEW", in: animation)
                
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.clear]), startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
                
                VStack(spacing: 10) {
                    HStack(alignment: .top) {
                        // Placeholder for close button (will be in overlay)
                        Color.clear
                            .frame(width: 44, height: 44)
                        
                        Spacer()
                        
                        VStack(alignment: .center, content: {
                            Text("Playlist from album")
                                .opacity(0.5)
                                .font(.caption)
                            
                            Text("Top Hits")
                                .font(.title2)
                        })
                        
                        Spacer()
                        
                        Image(systemName: "ellipsis")
                            .imageScale(.large)
                        
                    }
                    .padding(.horizontal)
                    .padding(.top, 80)
                    
                    GeometryReader {
                        let size = $0.size
                        // Use story image if available, otherwise use song cover
                        let imageURL = storyImageURL ?? songManager.song.cover
                        CachedAsyncImage(url: URL(string: imageURL)) { img in
                            img.resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                                .background(.white.opacity(0.1))
                                .clipShape(.rect(cornerRadius: 5))
                        }
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: animateContent ? 30 : 60, style: .continuous))
                    }
                    .matchedGeometryEffect(id: "SONGCOVER", in: animation)
                    .frame(width: size.width - 50)
                    .padding(.vertical, size.height < 700 ? 30 : 40)
                    
                    PlayerView(size)
                        .offset(y: animateContent ? 0 : size.height)
                }
                .padding(.top, safeArea.top + (safeArea.bottom == 0 ? 10 : 0))
                .padding(.bottom, safeArea.bottom == 0 ? 10 : safeArea.bottom)
                .padding(.horizontal, 25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .overlay(alignment: .topLeading) {
                // Close button in overlay to ensure it's always on top
                // Aligned with the right button (ellipsis) which is at padding.top 80
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        expandSheet = false
                        animateContent = false
                        offsetY = 0
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .imageScale(.large)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, safeArea.top + (safeArea.bottom == 0 ? 10 : 0) + 70)
                .padding(.leading, 25)
                .allowsHitTesting(true)
            }
            .contentShape(Rectangle())
            .offset(y: offsetY)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged( { value in
                        // Only handle drag if it's not in the top area (where close button is)
                        // Check if drag started in the top 100 points
                        if value.startLocation.y > 100 {
                            let translationY = value.translation.height
                            offsetY = (translationY > 0 ? translationY : 0)
                        }
                    }).onEnded( { value in
                        // Only handle drag end if it started in the lower area
                        if value.startLocation.y > 100 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if offsetY > size.height * 0.4 {
                                    expandSheet = false
                                    animateContent = false
                                    offsetY = 0
                                } else {
                                    offsetY = 0
                                }
                            }
                        }
                    })
            )
            .ignoresSafeArea(.container, edges: .all)
            
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear() {
            // Reset offset when view appears
            offsetY = 0
            withAnimation(.easeInOut(duration: 0.35)) {
                animateContent = true
            }
        }
        .onChange(of: expandSheet) { _, isExpanded in
            // Reset offset when view is closed
            if !isExpanded {
                offsetY = 0
                animateContent = false
            }
        }
        .sheet(isPresented: $showArtistView) {
            ArtistView(artistName: songManager.song.artist)
                .environmentObject(songManager)
                .environmentObject(authService)
        }
    }
    @ViewBuilder
    func PlayerView(_ mainSize: CGSize) -> some View {
        GeometryReader {
            let size = $0.size
            let spacing = size.height * 0.04
            
            // sizing t for more compact look
            VStack(spacing: spacing, content: {
                VStack(spacing: spacing, content: {
                    VStack(alignment: .center, spacing: 15, content: {
                        VStack(alignment: .center, spacing: 10, content: {
                            Text(songManager.song.title)
                                .font(.title)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            Button {
                                showArtistView = true
                            } label: {
                                Text(songManager.song.artist)
                                    .font(.title3)
                                    .foregroundStyle(.gray)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        })
                        .frame(maxWidth: .infinity)
                        
                        Slider(
                            value: Binding(
                                get: {
                                    songManager.duration > 0 ? songManager.currentTime : 0
                                },
                                set: { newValue in
                                    songManager.seek(to: newValue)
                                }
                            ),
                            in: 0...(songManager.duration > 0 ? songManager.duration : 1),
                            step: 1
                        )
                        .disabled(songManager.duration == 0)
                        .tint(.white)
                        
                        HStack {
                            Text(songManager.formattedCurrentTime)
                                .font(.caption)
                                .monospacedDigit()
                            
                            Spacer()
                            
                            Text(songManager.formattedDuration)
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .foregroundStyle(.gray)
                        
                        controlButtonsLayout()
                    })
                })
            })
        }
    }
    
    // MARK: - Control Buttons
    
    @ViewBuilder
    private func controlButtonsLayout() -> some View {
        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) {
                horizontalControlButtons(spacing: 20)
                verticalControlButtons()
            }
        } else {
            horizontalControlButtons(spacing: 18)
        }
    }
    
    @ViewBuilder
    private func horizontalControlButtons(spacing: CGFloat) -> some View {
        HStack(alignment: .center, spacing: spacing) {
            dislikeButton()
            shuffleButton()
            previousButton()
            playPauseButton()
            nextButton()
            repeatButton()
            likeButton()
        }
    }
    
    @ViewBuilder
    private func verticalControlButtons() -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                dislikeButton()
                shuffleButton()
                previousButton()
            }
            
            playPauseButton()
                .padding(.vertical, 6)
            
            HStack(spacing: 20) {
                nextButton()
                repeatButton()
                likeButton()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func dislikeButton() -> some View {
        Button(action: {
            songManager.toggleDislike()
        }) {
            Image(systemName: songManager.dislikeIconName)
                .font(.system(size: songManager.iconSize(for: songManager.song.dislikesCount, baseSize: 20), weight: .medium))
                .foregroundStyle(songManager.isCurrentSongDisliked ? Color.red : .gray)
        }
        .accessibilityLabel("Dislike song")
    }
    
    @ViewBuilder
    private func shuffleButton() -> some View {
        Button(action: {
            songManager.toggleShuffle()
        }) {
            Image(systemName: "shuffle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(songManager.isShuffling ? .white : .gray)
        }
        .accessibilityLabel(songManager.isShuffling ? "Disable shuffle" : "Enable shuffle")
    }
    
    @ViewBuilder
    private func previousButton() -> some View {
        Button(action: {
            songManager.playPrevious()
        }) {
            Image(systemName: "backward.end.fill")
                .font(.system(size: 20, weight: .medium))
        }
        .accessibilityLabel("Previous song")
    }
    
    @ViewBuilder
    private func playPauseButton() -> some View {
        Button(action: {
            songManager.togglePlayPause()
        }) {
            Image(systemName: songManager.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 30, weight: .semibold))
                .padding(21)
                .background(.white)
                .clipShape(Circle())
                .foregroundStyle(.black)
        }
        .accessibilityLabel(songManager.isPlaying ? "Pause" : "Play")
    }
    
    @ViewBuilder
    private func nextButton() -> some View {
        Button(action: {
            songManager.playNext()
        }) {
            Image(systemName: "forward.end.fill")
                .font(.system(size: 20, weight: .medium))
        }
        .accessibilityLabel("Next song")
    }
    
    @ViewBuilder
    private func repeatButton() -> some View {
        Button(action: {
            songManager.cycleRepeatMode()
        }) {
            Image(systemName: songManager.repeatIconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(songManager.repeatMode == .none ? .gray : .white)
        }
        .accessibilityLabel("Change repeat mode")
    }
    
    @ViewBuilder
    private func likeButton() -> some View {
        Button(action: {
            songManager.toggleLike()
        }) {
            Image(systemName: songManager.likeIconName)
                .font(.system(size: songManager.iconSize(for: songManager.song.likesCount, baseSize: 20), weight: .medium))
                .foregroundStyle(songManager.isCurrentSongLiked ? Color.pink : .gray)
        }
        .accessibilityLabel("Like song")
    }
}

#Preview {
    Home()
        .preferredColorScheme(.dark)
}

extension View {
    var deviceCornerRadius: CGFloat {
        let key = "_displayCornerRadius"
        if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.screen {
            if let cornerRadius = screen.value(forKey: key) as? CGFloat {
                return cornerRadius
            }
            return 0
        }
        return 0
    }
}
