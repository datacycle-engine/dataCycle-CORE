module DataCycleCore
  module OutdoorActive

    class Test2
      def test(message)
        temp = Test.new
        temp.test("msg from Test, not Test2")
      end
    end

  end
end
