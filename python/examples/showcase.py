from boombox import Boombox, MP4, RawData

bb1 = Boombox(MP4("bunny.mp4"), RawData(video=True, audio=False))

bb2 = Boombox(RawData(video=True, audio=False), MP4("negative_bunny.mp4"))

for packet in bb1.read():
    packet.payload = 255 - packet.payload
    bb2.write(packet)

bb2.close()
