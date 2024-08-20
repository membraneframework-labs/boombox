defmodule BoomboxTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions
  import Support.Async

  require Membrane.Pad, as: Pad
  require Logger

  alias Membrane.Testing
  alias Support.Compare

  @bbb_mp4_url "https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/big-buck-bunny/bun10s.mp4"
  @bbb_mp4 "test/fixtures/bun10s.mp4"
  @bbb_mp4_a "test/fixtures/bun10s_a.mp4"
  @bbb_mp4_v "test/fixtures/bun10s_v.mp4"

  @moduletag :tmp_dir

  @tag :file_file_mp4
  async_test "mp4 file -> mp4 file", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    Boombox.run(input: @bbb_mp4, output: output)
    Compare.compare(output, "test/fixtures/ref_bun10s_aac.mp4")
  end

  @tag :file_file_mp4_audio
  async_test "mp4 file -> mp4 file audio", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    Boombox.run(input: @bbb_mp4_a, output: output)
    Compare.compare(output, "test/fixtures/ref_bun10s_aac.mp4", kinds: [:audio])
  end

  @tag :file_file_mp4_video
  async_test "mp4 file -> mp4 file video", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    Boombox.run(input: @bbb_mp4_v, output: output)
    Compare.compare(output, "test/fixtures/ref_bun10s_aac.mp4", kinds: [:video])
  end

  @tag :http_file_mp4
  async_test "http mp4 -> mp4 file", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    Boombox.run(input: @bbb_mp4_url, output: output)
    Compare.compare(output, "test/fixtures/ref_bun10s_aac.mp4")
  end

  @tag :file_webrtc
  async_test "mp4 file -> webrtc -> mp4 file", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    signaling = Membrane.WebRTC.SignalingChannel.new()
    t = Task.async(fn -> Boombox.run(input: @bbb_mp4, output: {:webrtc, signaling}) end)
    Boombox.run(input: {:webrtc, signaling}, output: output)
    Task.await(t)
    Compare.compare(output, "test/fixtures/ref_bun10s_opus_aac.mp4")
  end

  @tag :http_webrtc
  async_test "http mp4 -> webrtc -> mp4 file", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    signaling = Membrane.WebRTC.SignalingChannel.new()
    t = Task.async(fn -> Boombox.run(input: @bbb_mp4_url, output: {:webrtc, signaling}) end)
    Boombox.run(input: {:webrtc, signaling}, output: output)
    Task.await(t)
    Compare.compare(output, "test/fixtures/ref_bun10s_opus_aac.mp4")
  end

  @tag :webrtc_audio
  async_test "mp4 -> webrtc -> mp4 audio", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    signaling = Membrane.WebRTC.SignalingChannel.new()

    t =
      Task.async(fn -> Boombox.run(input: @bbb_mp4_a, output: {:webrtc, signaling}) end)

    Boombox.run(input: {:webrtc, signaling}, output: "#{tmp}/output.mp4")
    Task.await(t)
    Compare.compare(output, "test/fixtures/ref_bun10s_opus_aac.mp4", kinds: [:audio])
  end

  @tag :webrtc_video
  async_test "mp4 -> webrtc -> mp4 video", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    signaling = Membrane.WebRTC.SignalingChannel.new()

    t =
      Task.async(fn -> Boombox.run(input: @bbb_mp4_v, output: {:webrtc, signaling}) end)

    Boombox.run(input: {:webrtc, signaling}, output: output)
    Task.await(t)
    Compare.compare(output, "test/fixtures/ref_bun10s_opus_aac.mp4", kinds: [:video])
  end

  @tag :webrtc2
  async_test "mp4 -> webrtc -> webrtc -> mp4", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    signaling1 = Membrane.WebRTC.SignalingChannel.new()
    signaling2 = Membrane.WebRTC.SignalingChannel.new()

    t1 =
      Task.async(fn -> Boombox.run(input: @bbb_mp4, output: {:webrtc, signaling1}) end)

    t2 =
      Task.async(fn ->
        Boombox.run(input: {:webrtc, signaling1}, output: {:webrtc, signaling2})
      end)

    Boombox.run(input: {:webrtc, signaling2}, output: output)
    Task.await(t1)
    Task.await(t2)
    Compare.compare(output, "test/fixtures/ref_bun10s_opus2_aac.mp4")
  end

  @tag :rtmp
  async_test "rtmp -> mp4", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    url = "rtmp://localhost:5000/app/stream_key"
    t = Task.async(fn -> Boombox.run(input: url, output: output) end)

    # Wait for boombox to be ready
    Process.sleep(200)
    p = send_rtmp(url)
    Task.await(t, 30_000)
    Testing.Pipeline.terminate(p)
    Compare.compare(output, "test/fixtures/ref_bun10s_aac.mp4")
  end

  @tag :rtmp_webrtc
  async_test "rtmp -> webrtc -> mp4", %{tmp_dir: tmp} do
    output = Path.join(tmp, "output.mp4")
    url = "rtmp://localhost:5002/app/stream_key"
    signaling = Membrane.WebRTC.SignalingChannel.new()

    t1 =
      Task.async(fn -> Boombox.run(input: url, output: {:webrtc, signaling}) end)

    t2 =
      Task.async(fn -> Boombox.run(input: {:webrtc, signaling}, output: output) end)

    # Wait for boombox to be ready
    Process.sleep(200)
    p = send_rtmp(url)
    Task.await(t1, 30_000)
    Task.await(t2)
    Testing.Pipeline.terminate(p)
    Compare.compare(output, "test/fixtures/ref_bun10s_opus_aac.mp4")
  end

  @tag :file_hls
  async_test "mp4 file -> hls", %{tmp_dir: tmp} do
    manifest_filename = Path.join(tmp, "index.m3u8")
    Boombox.run(input: @bbb_mp4, output: manifest_filename)
    ref_path = "test/fixtures/ref_bun10s_aac_hls"
    Compare.compare(tmp, ref_path, format: :hls)

    Enum.zip(
      Path.join(tmp, "*.mp4") |> Path.wildcard(),
      Path.join(ref_path, "*.mp4") |> Path.wildcard()
    )
    |> Enum.each(fn {output_file, ref_file} ->
      assert File.read!(output_file) == File.read!(ref_file)
    end)
  end

  @tag :rtmp_hls
  async_test "rtmp -> hls", %{tmp_dir: tmp} do
    manifest_filename = Path.join(tmp, "index.m3u8")
    url = "rtmp://localhost:5003/app/stream_key"
    ref_path = "test/fixtures/ref_bun10s_aac_hls"
    t = Task.async(fn -> Boombox.run(input: url, output: manifest_filename) end)

    # Wait for boombox to be ready
    Process.sleep(200)
    p = send_rtmp(url)
    Task.await(t, 30_000)
    Testing.Pipeline.terminate(p)
    Compare.compare(tmp, ref_path, format: :hls)

    Enum.zip(
      Path.join(tmp, "*.mp4") |> Path.wildcard(),
      Path.join(ref_path, "*.mp4") |> Path.wildcard()
    )
    |> Enum.each(fn {output_file, ref_file} ->
      assert File.read!(output_file) == File.read!(ref_file)
    end)
  end

  @tag :rtsp_hls
  async_test "rtsp -> hls", %{tmp_dir: tmp} do
    # tmp = "tmp/BoomboxTest.AsyncTest_AD1CB48DEBDAAADADA4C2596/test-rtsp----hls-88891efc"
    manifest_filename = Path.join(tmp, "index.m3u8")
    Boombox.run(input: "rtsp://localhost:8554/livestream", output: manifest_filename)
    # IO.inspect("boombox finished")
    # ref_path = "output"
    ref_path = "test/fixtures/ref_bun10s_aac_hls"
    Compare.compare(tmp, ref_path, kinds: [:video], format: :hls)

    # Enum.zip(
    # Path.join(tmp, "*.mp4") |> Path.wildcard(),
    # Path.join(ref_path, "*.mp4") |> Path.wildcard()
    # )
    # |> Enum.each(fn {output_file, ref_file} ->
    # assert File.read!(output_file) == File.read!(ref_file)
    # end)
  end

  defp send_rtmp(url) do
    p =
      Testing.Pipeline.start_link_supervised!(
        spec:
          child(%Membrane.File.Source{location: @bbb_mp4, seekable?: true})
          |> child(:demuxer, %Membrane.MP4.Demuxer.ISOM{optimize_for_non_fast_start?: true})
      )

    assert_pipeline_notified(p, :demuxer, {:new_tracks, tracks})

    [{audio_id, %Membrane.AAC{}}, {video_id, %Membrane.H264{}}] =
      Enum.sort_by(tracks, fn {_id, %format{}} -> format end)

    Testing.Pipeline.execute_actions(p,
      spec: [
        get_child(:demuxer)
        |> via_out(Pad.ref(:output, video_id))
        |> child(Membrane.Realtimer)
        |> child(:video_parser, %Membrane.H264.Parser{
          output_stream_structure: :avc1
        })
        |> via_in(Pad.ref(:video, 0))
        |> get_child(:rtmp_sink),
        get_child(:demuxer)
        |> via_out(Pad.ref(:output, audio_id))
        |> child(Membrane.Realtimer)
        |> child(:audio_parser, %Membrane.AAC.Parser{
          out_encapsulation: :none,
          output_config: :esds
        })
        |> via_in(Pad.ref(:audio, 0))
        |> get_child(:rtmp_sink),
        child(:rtmp_sink, %Membrane.RTMP.Sink{rtmp_url: url})
      ]
    )

    p
  end
end
