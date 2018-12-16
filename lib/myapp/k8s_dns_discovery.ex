defmodule Myapp.K8sDiscovery do
  @moduledoc """
  GenServer Module responsible to connect existenting nodes through Kubernetes DNS.
  """

  use GenServer

  require Logger

  # try to connect every 5 seconds
  @connect_interval 5000

  @doc false
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    k8s_dns_name = Application.fetch_env(:myapp, :k8s_dns_name)

    case k8s_dns_name do
      {:ok, value} ->
        send(self(), :connect)
        {:ok, to_char_list(value)}

      :error ->
        {:ok, []}
    end
  end

  def handle_info(:connect, k8s_dns_name) do
    case :inet_tcp.getaddrs(k8s_dns_name) do
      {:ok, ips} ->
        app_pod_ip = Application.get_env(:myapp, :app_pod_ip)
        app_cluster_name = Application.get_env(:myapp, :app_cluster_name)

        for {a, b, c, d} <- ips do
          if app_pod_ip != "#{a}.#{b}.#{c}.#{d}" do
            Node.connect(:"#{app_cluster_name}@#{a}.#{b}.#{c}.#{d}")
          end
        end

      {:error, reason} ->
        "error resolving #{inspect(k8s_dns_name)}: #{inspect(reason)}"
        |> Logger.error()
    end

    "nodes: #{inspect(Node.list())}"
    |> Logger.info()

    Process.send_after(self(), :connect, @connect_interval)

    {:noreply, k8s_dns_name}
  end
end
