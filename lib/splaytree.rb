# frozen_string_literal: true

require_relative 'splaytree/version'
require_relative 'splaytree/node'

class Splaytree
  include Enumerable

  attr_reader :root, :size
  alias_method :length, :size

  def initialize
    @root = nil
    @size = 0
  end

  def inspect
    format( "#<Splaytree: tree=%s>", report.inspect )
  end

  def empty?
    @root.nil?
  end

  def key?(key)
    !!get(key)
  end

  def higher(key)
    return if empty?
    get(key)
    return @root.to_h if @root.key > key
    get_one_higher_of_root
  end

  def lower(key)
    return if empty?
    get(key)
    return @root.to_h if @root.key < key
    get_one_lower_of_root
  end

  def ceiling(key)
    return if empty?
    get(key)
    return @root.to_h if @root.key >= key
    get_one_higher_of_root
  end

  def floor(key)
    return if empty?
    get(key)
    return @root.to_h if @root.key <= key
    get_one_lower_of_root
  end

  def min
    return if empty?
    node = @root
    node = node.left while node.left
    splay(node)
    node.to_h
  end

  def max
    return if empty?
    node = @root
    node = node.right while node.right
    splay(node)
    node.to_h
  end

  def height
    subtree_height = -> (node) do
      return 0 unless node
      left = 1 + subtree_height.call(node.left)
      right = 1 + subtree_height.call(node.right)
      left > right ? left : right
    end
    subtree_height.call(@root)
  end

  def duplicates(key)
    return if empty?
    get(key)
    return if @root.key != key
    @root.duplicates + [@root.value]
  end

  def get(key)
    return if empty?
    node = @root
    value = nil
    loop do
      case key <=> node.key
      when 0
        value = node.value
        break
      when -1
        break if node.left.nil?
        node = node.left
      when 1
        break if node.right.nil?
        node = node.right
      else
        raise TypeError, 'Keys should be comparable!'
      end
    end
    splay(node)
    value
  end
  alias_method :[], :get

  def insert(key, value)
    node = Node.new(key, value)
    if @root
      current = @root
      loop do
        case key <=> current.key
        when 0
          node = current
          node.add_duplicate!(value)
          break
        when -1
          unless current.left
            current.set_left(node)
            break
          end
          current = current.left
        when 1
          unless current.right
            current.set_right(node)
            break
          end
          current = current.right
        else
          raise TypeError, 'Keys should be comparable!'
        end
      end
    end
    splay(node)
    @size += 1
    true
  end
  alias_method :[]=, :insert

  def update(key, value)
    return false if empty?
    get(key)
    return false if @root.key != key
    @root.value = value
    true
  end

  def remove(key)
    return if empty?
    get(key)
    return if @root.key != key
    if @root.duplicates?
      deleted = @root.remove_duplicate!
    else
      deleted = @root.value
      if @root.left.nil?
        @root = @root.right
        @root.parent = nil
      else
        right = @root.right
        @root = @root.left
        @root.parent = nil
        get(key)
        @root.set_right(right)
      end
    end
    @size -= 1
    deleted
  end

  def clear
    @root = nil
    @size = 0
  end

  def bound( low, high )
    block_given? or return enum_for(__method__, low, high)
    return if empty?
    floor(high)
    ceiling(low)
    stack = []
    node = @root
    loop do
      if node
        stack.push(node)
        left = node.left && node.left.key
        node = ( left && left >= low ) ? node.left : nil
      else
        break if stack.empty?
        node = stack.pop
        node.duplicates.each do |value|
          yield(node.key,value)
        end
        yield(node.key,node.value)
        right = node.right && node.right.key
        node = ( right && right <= high ) ? node.right : nil
      end
    end
  end
  
  def each_node
    block_given? or return enum_for(__method__)
    return if empty?
    stack = []
    node = @root
    loop do
      if node
        stack.push(node)
        node = node.left
      else
        break if stack.empty?
        node = stack.pop
        yield(node)
        node = node.right
      end
    end
  end

  def each
    block_given? or return enum_for(__method__)
    each_node{ |node|
      node.duplicates.each do |value|
        yield(node.key,value)
      end
      yield(node.key,node.value)
    }
  end

  def each_key
    block_given? or return enum_for(__method__)
    each { |key,_| yield key }
  end

  def each_value
    block_given? or return enum_for(__method__)
    each { |_,val| yield val }
  end

  def keys
    each_key.to_a
  end

  def values
    each_value.to_a
  end

  def display
    print_tree = -> (node, depth) do
      return unless node
      print_tree.call(node.right, depth + 1)
      printf "%s%s\n", ' '*depth, node.key
      print_tree.call(node.left, depth + 1)
    end
    print_tree.call(@root, 0)
  end

  def report
    return if empty?
    result = []
    Enumerator.new do |y|
      each_node do |node|
        node.duplicates.each { |value|
          y << Node.new(node.key, value, node)
        }
        y << node
      end
    end.each do |node|
      item = {
        node: node.key,
        parent: node.parent && node.parent.key,
        left: node.left && node.left.key,
        right: node.right && node.right.key
      }
      result << item
    end
    result
  end

  private

  def get_one_higher_of_root
    return if @root.right.nil?
    node = @root.right
    node = node.left while node.left
    splay(node)
    node.to_h
  end

  def get_one_lower_of_root
    return if @root.left.nil?
    node = @root.left
    node = node.right while node.right
    splay(node)
    node.to_h
  end

  def splay(node)
    until node.root?
      parent = node.parent
      if parent.root?
        node.rotate
      elsif node.zigzig?
        parent.rotate
        node.rotate
      else
        node.rotate
        node.rotate
      end
    end
    @root = node
  end
end


