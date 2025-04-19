defmodule ElixirChallenge.PrimeFactorsSumFinder do
  @doc """
  A function which finds and returns a number in the `candidates` list
  for which the sum of its prime factors is equal `target_sum`.

  ## Examples

      iex> ElixirChallenge.PrimeFactorsSumFinder.find_number_with_factors_sum([8, 13, 12], 6)
      8

      iex> ElixirChallenge.PrimeFactorsSumFinder.find_number_with_factors_sum([8, 13, 12], 7)
      12

  """
  @spec find_number_with_factors_sum([integer()], integer()) :: integer()
  def find_number_with_factors_sum(candidates, target_sum) do
    candidates = Enum.sort(candidates)
    threads_amount = System.schedulers_online()
    me = self()

    pid =
      spawn(fn ->
        find_number_worker(me, candidates, target_sum, threads_amount)
      end)

    receive do
      {:found, candidate} ->
        Process.exit(pid, :kill)
        candidate
    end
  end

  def find_number_worker(
        master,
        candidates,
        target_sum,
        threads_amount
      ) do
    me = self()

    candidates
    |> Enum.take(threads_amount)
    |> Enum.each(fn candidate ->
      spawn_link(fn -> parallel_helper(me, candidate, target_sum) end)
    end)

    rest = candidates |> Enum.drop(threads_amount)
    found = continue_find_number(rest, target_sum)
    send(master, {:found, found})
  end

  def parallel_helper(master, candidate, target_sum) do
    if check(candidate, target_sum) do
      send(master, {:good, candidate})
    else
      send(master, :bad)
    end
  end

  def continue_find_number(candidates, target_sum) do
    me = self()

    receive do
      :bad ->
        case candidates do
          [candidate | rest] ->
            spawn_link(fn -> parallel_helper(me, candidate, target_sum) end)
            continue_find_number(rest, target_sum)

          [] ->
            continue_find_number([], target_sum)
        end

      {:good, found} ->
        found
    end
  end

  def check(number, target) do
    case divs(number, target, 2) do
      :good ->
        true

      :bad ->
        false

      {:continue, start_num, start_target} ->
        test(start_num, start_target, 3)
    end
  end

  def test(number, target, divisor) do
    case divs(number, target, divisor) do
      :good ->
        true

      :bad ->
        false

      {:continue, start_num, start_target} ->
        test(start_num, start_target, divisor + 2)
    end
  end

  def divs(number, target, divisor) do
    if rem(number, divisor) == 0 do
      {number, target} = divs_helper(div(number, divisor), target - divisor, divisor)

      cond do
        # finished factoring
        number == 1 ->
          if target == 0 do
            :good
          else
            :bad
          end

        # target missed (obviously)
        target <= 0 ->
          :bad

        # target missed (no way to reach it)
        target > number ->
          :bad

        # target missed (sum can only be larger than it)
        target <= divisor ->
          :bad

        # hit prime
        divisor * divisor > number ->
          if number == target do
            :good
          else
            :bad
          end

        true ->
          {:continue, number, target}
      end
    else
      cond do
        # hit prime
        divisor * divisor > number ->
          if number == target do
            :good
          else
            :bad
          end

        # target missed (sum can only be larger than it)
        target <= divisor ->
          :bad

        true ->
          {:continue, number, target}
      end
    end
  end

  def divs_helper(number, target, divisor) do
    if rem(number, divisor) == 0 do
      divs_helper(div(number, divisor), target - divisor, divisor)
    else
      {number, target}
    end
  end
end
